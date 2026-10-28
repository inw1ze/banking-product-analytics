DROP SCHEMA IF EXISTS clean CASCADE;

CREATE SCHEMA clean;

CREATE TABLE clean.customers AS
WITH ranked_customers AS (
    SELECT
        customer_id,
        registration_ts,
        birth_date,
        gender,
        region,
        acquisition_channel,
        income_band,
        risk_score,
        is_premium,
        first_name,
        last_name,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY registration_ts, customer_id
        ) AS row_number
    FROM raw.customers
)
SELECT
    customer_id,
    registration_ts,
    birth_date,
    gender,
    region,
    acquisition_channel,
    income_band,
    risk_score,
    is_premium,
    first_name,
    last_name
FROM ranked_customers
WHERE row_number = 1
  AND customer_id IS NOT NULL
  AND registration_ts IS NOT NULL
  AND birth_date IS NOT NULL
  AND birth_date <= registration_ts::DATE
  AND gender IN ('F', 'M')
  AND region IS NOT NULL
  AND acquisition_channel IN (
      'organic',
      'paid_search',
      'partner',
      'referral',
      'social',
      'offline'
  )
  AND (risk_score IS NULL OR risk_score BETWEEN 1 AND 100)
  AND is_premium IS NOT NULL
  AND first_name IS NOT NULL
  AND last_name IS NOT NULL;

ALTER TABLE clean.customers
    ADD CONSTRAINT customers_pk PRIMARY KEY (customer_id);

CREATE TABLE clean.accounts AS
WITH ranked_accounts AS (
    SELECT
        account_id,
        customer_id,
        opened_at,
        closed_at,
        account_type,
        currency,
        status,
        current_balance,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY opened_at, account_id
        ) AS row_number
    FROM raw.accounts
)
SELECT
    accounts.account_id,
    accounts.customer_id,
    accounts.opened_at,
    accounts.closed_at,
    accounts.account_type,
    accounts.currency,
    accounts.status,
    accounts.current_balance
FROM ranked_accounts accounts
JOIN clean.customers customers
    ON customers.customer_id = accounts.customer_id
WHERE accounts.row_number = 1
  AND accounts.account_id IS NOT NULL
  AND accounts.opened_at IS NOT NULL
  AND accounts.opened_at >= customers.registration_ts::DATE
  AND (
      accounts.closed_at IS NULL
      OR accounts.closed_at >= accounts.opened_at
  )
  AND accounts.account_type IN ('debit', 'current', 'savings', 'credit')
  AND accounts.currency IN ('RUB', 'USD', 'EUR')
  AND accounts.status IN ('active', 'blocked', 'closed')
  AND accounts.current_balance IS NOT NULL;

ALTER TABLE clean.accounts
    ADD CONSTRAINT accounts_pk PRIMARY KEY (account_id),
    ADD CONSTRAINT accounts_customer_fk
        FOREIGN KEY (customer_id)
        REFERENCES clean.customers (customer_id);

CREATE TABLE clean.cards AS
WITH ranked_cards AS (
    SELECT
        card_id,
        account_id,
        issued_at,
        activated_at,
        card_type,
        payment_system,
        status,
        expires_at,
        ROW_NUMBER() OVER (
            PARTITION BY card_id
            ORDER BY issued_at, card_id
        ) AS row_number
    FROM raw.cards
)
SELECT
    cards.card_id,
    cards.account_id,
    cards.issued_at,
    cards.activated_at,
    cards.card_type,
    cards.payment_system,
    cards.status,
    cards.expires_at
FROM ranked_cards cards
JOIN clean.accounts accounts
    ON accounts.account_id = cards.account_id
WHERE cards.row_number = 1
  AND cards.card_id IS NOT NULL
  AND cards.issued_at IS NOT NULL
  AND cards.issued_at >= accounts.opened_at
  AND (
      cards.activated_at IS NULL
      OR cards.activated_at >= cards.issued_at
  )
  AND cards.card_type IN ('virtual', 'physical')
  AND cards.payment_system IN ('MIR', 'Visa', 'Mastercard')
  AND cards.status IN ('issued', 'active', 'blocked')
  AND cards.expires_at > cards.issued_at;

ALTER TABLE clean.cards
    ADD CONSTRAINT cards_pk PRIMARY KEY (card_id),
    ADD CONSTRAINT cards_account_fk
        FOREIGN KEY (account_id)
        REFERENCES clean.accounts (account_id);

CREATE TABLE clean.merchants AS
WITH ranked_merchants AS (
    SELECT
        merchant_id,
        merchant_name,
        category,
        city,
        country,
        risk_level,
        ROW_NUMBER() OVER (
            PARTITION BY merchant_id
            ORDER BY merchant_name, merchant_id
        ) AS row_number
    FROM raw.merchants
)
SELECT
    merchant_id,
    merchant_name,
    category,
    city,
    country,
    risk_level
FROM ranked_merchants
WHERE row_number = 1
  AND merchant_id IS NOT NULL
  AND merchant_name IS NOT NULL
  AND category IS NOT NULL
  AND city IS NOT NULL
  AND country IS NOT NULL
  AND risk_level IN ('low', 'medium', 'high');

ALTER TABLE clean.merchants
    ADD CONSTRAINT merchants_pk PRIMARY KEY (merchant_id);

CREATE TABLE clean.transactions AS
WITH ranked_transactions AS (
    SELECT
        transaction_id,
        account_id,
        card_id,
        merchant_id,
        transaction_ts,
        transaction_type,
        amount,
        currency,
        fee_amount,
        status,
        channel,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY transaction_ts, transaction_id
        ) AS row_number
    FROM raw.transactions
)
SELECT
    transactions.transaction_id,
    transactions.account_id,
    cards.card_id,
    merchants.merchant_id,
    transactions.transaction_ts,
    transactions.transaction_type,
    transactions.amount,
    transactions.currency,
    transactions.fee_amount,
    transactions.status,
    transactions.channel,
    CASE
        WHEN transactions.transaction_type IN ('card_purchase', 'refund')
            THEN cards.card_id IS NOT NULL
        ELSE TRUE
    END AS card_reference_complete,
    CASE
        WHEN transactions.transaction_type IN ('card_purchase', 'refund')
            THEN merchants.merchant_id IS NOT NULL
        ELSE TRUE
    END AS merchant_reference_complete
FROM ranked_transactions transactions
JOIN clean.accounts accounts
    ON accounts.account_id = transactions.account_id
LEFT JOIN clean.cards cards
    ON cards.card_id = transactions.card_id
   AND cards.account_id = transactions.account_id
   AND cards.issued_at <= transactions.transaction_ts::DATE
LEFT JOIN clean.merchants merchants
    ON merchants.merchant_id = transactions.merchant_id
WHERE transactions.row_number = 1
  AND transactions.transaction_id IS NOT NULL
  AND transactions.transaction_ts IS NOT NULL
  AND transactions.transaction_ts::DATE >= accounts.opened_at
  AND transactions.transaction_type IN (
      'card_purchase',
      'transfer',
      'cash_withdrawal',
      'cash_deposit',
      'refund'
  )
  AND transactions.amount > 0
  AND transactions.currency = accounts.currency
  AND transactions.fee_amount >= 0
  AND transactions.status IN ('completed', 'declined', 'reversed')
  AND transactions.channel IN (
      'online',
      'pos',
      'web',
      'atm',
      'branch',
      'mobile'
  );

ALTER TABLE clean.transactions
    ADD CONSTRAINT transactions_pk PRIMARY KEY (transaction_id),
    ADD CONSTRAINT transactions_account_fk
        FOREIGN KEY (account_id)
        REFERENCES clean.accounts (account_id),
    ADD CONSTRAINT transactions_card_fk
        FOREIGN KEY (card_id)
        REFERENCES clean.cards (card_id),
    ADD CONSTRAINT transactions_merchant_fk
        FOREIGN KEY (merchant_id)
        REFERENCES clean.merchants (merchant_id);

CREATE TABLE clean.sessions AS
WITH ranked_sessions AS (
    SELECT
        session_id,
        customer_id,
        started_at,
        ended_at,
        channel,
        device_os,
        events_count,
        auth_success,
        ROW_NUMBER() OVER (
            PARTITION BY session_id
            ORDER BY started_at, session_id
        ) AS row_number
    FROM raw.sessions
)
SELECT
    sessions.session_id,
    sessions.customer_id,
    sessions.started_at,
    sessions.ended_at,
    sessions.channel,
    sessions.device_os,
    sessions.events_count,
    sessions.auth_success
FROM ranked_sessions sessions
JOIN clean.customers customers
    ON customers.customer_id = sessions.customer_id
WHERE sessions.row_number = 1
  AND sessions.session_id IS NOT NULL
  AND sessions.started_at IS NOT NULL
  AND sessions.ended_at IS NOT NULL
  AND sessions.ended_at >= sessions.started_at
  AND sessions.channel IN ('mobile', 'web')
  AND sessions.device_os IN ('iOS', 'Android', 'Windows', 'macOS')
  AND sessions.events_count >= 0
  AND sessions.auth_success IS NOT NULL;

ALTER TABLE clean.sessions
    ADD CONSTRAINT sessions_pk PRIMARY KEY (session_id),
    ADD CONSTRAINT sessions_customer_fk
        FOREIGN KEY (customer_id)
        REFERENCES clean.customers (customer_id);
