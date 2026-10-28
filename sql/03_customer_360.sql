CREATE SCHEMA IF NOT EXISTS mart;

DROP TABLE IF EXISTS mart.customer_360;

CREATE TABLE mart.customer_360 AS
WITH account_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS account_count,
        COUNT(*) FILTER (WHERE status = 'active') AS active_account_count,
        MIN(opened_at) AS first_account_opened_at,
        SUM(current_balance) AS total_balance
    FROM clean.accounts
    GROUP BY customer_id
),
card_metrics AS (
    SELECT
        accounts.customer_id,
        COUNT(*) AS card_count,
        COUNT(*) FILTER (WHERE cards.activated_at IS NOT NULL) AS activated_card_count,
        COUNT(*) FILTER (WHERE cards.status = 'active') AS active_card_count,
        MIN(cards.issued_at) AS first_card_issued_at,
        MIN(cards.activated_at) AS first_card_activated_at
    FROM clean.cards cards
    JOIN clean.accounts accounts
        ON accounts.account_id = cards.account_id
    GROUP BY accounts.customer_id
),
transaction_metrics AS (
    SELECT
        accounts.customer_id,
        COUNT(*) AS transaction_count,
        COUNT(*) FILTER (
            WHERE transactions.status = 'completed'
        ) AS completed_transaction_count,
        COUNT(DISTINCT transactions.transaction_ts::DATE) FILTER (
            WHERE transactions.status = 'completed'
        ) AS active_transaction_days,
        SUM(transactions.amount) FILTER (
            WHERE transactions.status = 'completed'
        ) AS transaction_volume,
        AVG(transactions.amount) FILTER (
            WHERE transactions.status = 'completed'
        ) AS average_transaction_amount,
        SUM(transactions.fee_amount) FILTER (
            WHERE transactions.status = 'completed'
        ) AS fee_revenue,
        MIN(transactions.transaction_ts) FILTER (
            WHERE transactions.status = 'completed'
        ) AS first_transaction_ts,
        MAX(transactions.transaction_ts) FILTER (
            WHERE transactions.status = 'completed'
        ) AS last_transaction_ts
    FROM clean.transactions transactions
    JOIN clean.accounts accounts
        ON accounts.account_id = transactions.account_id
    GROUP BY accounts.customer_id
),
session_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS session_count,
        COUNT(*) FILTER (WHERE auth_success) AS successful_auth_count,
        SUM(events_count) AS event_count,
        MIN(started_at) AS first_session_ts,
        MAX(started_at) AS last_session_ts
    FROM clean.sessions
    GROUP BY customer_id
)
SELECT
    customers.customer_id,
    customers.registration_ts,
    customers.birth_date,
    customers.gender,
    customers.region,
    customers.acquisition_channel,
    customers.income_band,
    customers.risk_score,
    customers.is_premium,
    COALESCE(accounts.account_count, 0) AS account_count,
    COALESCE(accounts.active_account_count, 0) AS active_account_count,
    accounts.first_account_opened_at,
    COALESCE(accounts.total_balance, 0) AS total_balance,
    COALESCE(cards.card_count, 0) AS card_count,
    COALESCE(cards.activated_card_count, 0) AS activated_card_count,
    COALESCE(cards.active_card_count, 0) AS active_card_count,
    cards.first_card_issued_at,
    cards.first_card_activated_at,
    COALESCE(transactions.transaction_count, 0) AS transaction_count,
    COALESCE(
        transactions.completed_transaction_count,
        0
    ) AS completed_transaction_count,
    COALESCE(transactions.active_transaction_days, 0) AS active_transaction_days,
    COALESCE(transactions.transaction_volume, 0) AS transaction_volume,
    ROUND(
        COALESCE(transactions.average_transaction_amount, 0),
        2
    ) AS average_transaction_amount,
    COALESCE(transactions.fee_revenue, 0) AS fee_revenue,
    transactions.first_transaction_ts,
    transactions.last_transaction_ts,
    COALESCE(sessions.session_count, 0) AS session_count,
    COALESCE(sessions.successful_auth_count, 0) AS successful_auth_count,
    COALESCE(sessions.event_count, 0) AS event_count,
    sessions.first_session_ts,
    sessions.last_session_ts,
    COALESCE(
        GREATEST(
            transactions.last_transaction_ts,
            sessions.last_session_ts
        ),
        transactions.last_transaction_ts,
        sessions.last_session_ts,
        customers.registration_ts
    ) AS last_activity_ts
FROM clean.customers customers
LEFT JOIN account_metrics accounts
    ON accounts.customer_id = customers.customer_id
LEFT JOIN card_metrics cards
    ON cards.customer_id = customers.customer_id
LEFT JOIN transaction_metrics transactions
    ON transactions.customer_id = customers.customer_id
LEFT JOIN session_metrics sessions
    ON sessions.customer_id = customers.customer_id;

ALTER TABLE mart.customer_360
    ADD CONSTRAINT customer_360_pk PRIMARY KEY (customer_id);
