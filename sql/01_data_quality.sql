CREATE SCHEMA IF NOT EXISTS audit;

CREATE OR REPLACE VIEW audit.data_quality_summary AS
SELECT
    'customers'::TEXT AS table_name,
    'duplicate_customer_id'::TEXT AS check_name,
    COALESCE(SUM(duplicate_count - 1), 0)::BIGINT AS issue_count
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM raw.customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'accounts',
    'duplicate_account_id',
    COALESCE(SUM(duplicate_count - 1), 0)::BIGINT
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM raw.accounts
    GROUP BY account_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'cards',
    'duplicate_card_id',
    COALESCE(SUM(duplicate_count - 1), 0)::BIGINT
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM raw.cards
    GROUP BY card_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'merchants',
    'duplicate_merchant_id',
    COALESCE(SUM(duplicate_count - 1), 0)::BIGINT
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM raw.merchants
    GROUP BY merchant_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'transactions',
    'duplicate_transaction_id',
    COALESCE(SUM(duplicate_count - 1), 0)::BIGINT
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM raw.transactions
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'sessions',
    'duplicate_session_id',
    COALESCE(SUM(duplicate_count - 1), 0)::BIGINT
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM raw.sessions
    GROUP BY session_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT
    'customers',
    'missing_required_field',
    COUNT(*)
FROM raw.customers
WHERE customer_id IS NULL
   OR registration_ts IS NULL
   OR birth_date IS NULL
   OR gender IS NULL
   OR region IS NULL
   OR acquisition_channel IS NULL
   OR is_premium IS NULL
   OR first_name IS NULL
   OR last_name IS NULL

UNION ALL

SELECT
    'accounts',
    'missing_required_field',
    COUNT(*)
FROM raw.accounts
WHERE account_id IS NULL
   OR customer_id IS NULL
   OR opened_at IS NULL
   OR account_type IS NULL
   OR currency IS NULL
   OR status IS NULL
   OR current_balance IS NULL

UNION ALL

SELECT
    'cards',
    'missing_required_field',
    COUNT(*)
FROM raw.cards
WHERE card_id IS NULL
   OR account_id IS NULL
   OR issued_at IS NULL
   OR card_type IS NULL
   OR payment_system IS NULL
   OR status IS NULL
   OR expires_at IS NULL

UNION ALL

SELECT
    'merchants',
    'missing_required_field',
    COUNT(*)
FROM raw.merchants
WHERE merchant_id IS NULL
   OR merchant_name IS NULL
   OR category IS NULL
   OR city IS NULL
   OR country IS NULL
   OR risk_level IS NULL

UNION ALL

SELECT
    'transactions',
    'missing_required_field',
    COUNT(*)
FROM raw.transactions
WHERE transaction_id IS NULL
   OR account_id IS NULL
   OR transaction_ts IS NULL
   OR transaction_type IS NULL
   OR amount IS NULL
   OR currency IS NULL
   OR fee_amount IS NULL
   OR status IS NULL
   OR channel IS NULL

UNION ALL

SELECT
    'sessions',
    'missing_required_field',
    COUNT(*)
FROM raw.sessions
WHERE session_id IS NULL
   OR customer_id IS NULL
   OR started_at IS NULL
   OR ended_at IS NULL
   OR channel IS NULL
   OR device_os IS NULL
   OR events_count IS NULL
   OR auth_success IS NULL

UNION ALL

SELECT
    'accounts',
    'customer_not_found',
    COUNT(*)
FROM raw.accounts accounts
LEFT JOIN raw.customers customers
    ON customers.customer_id = accounts.customer_id
WHERE customers.customer_id IS NULL

UNION ALL

SELECT
    'cards',
    'account_not_found',
    COUNT(*)
FROM raw.cards cards
LEFT JOIN raw.accounts accounts
    ON accounts.account_id = cards.account_id
WHERE accounts.account_id IS NULL

UNION ALL

SELECT
    'transactions',
    'account_not_found',
    COUNT(*)
FROM raw.transactions transactions
LEFT JOIN raw.accounts accounts
    ON accounts.account_id = transactions.account_id
WHERE accounts.account_id IS NULL

UNION ALL

SELECT
    'transactions',
    'card_not_found',
    COUNT(*)
FROM raw.transactions transactions
LEFT JOIN raw.cards cards
    ON cards.card_id = transactions.card_id
WHERE transactions.card_id IS NOT NULL
  AND cards.card_id IS NULL

UNION ALL

SELECT
    'transactions',
    'merchant_not_found',
    COUNT(*)
FROM raw.transactions transactions
LEFT JOIN raw.merchants merchants
    ON merchants.merchant_id = transactions.merchant_id
WHERE transactions.merchant_id IS NOT NULL
  AND merchants.merchant_id IS NULL

UNION ALL

SELECT
    'sessions',
    'customer_not_found',
    COUNT(*)
FROM raw.sessions sessions
LEFT JOIN raw.customers customers
    ON customers.customer_id = sessions.customer_id
WHERE customers.customer_id IS NULL

UNION ALL

SELECT
    'customers',
    'invalid_customer_values',
    COUNT(*)
FROM raw.customers
WHERE birth_date > registration_ts::DATE
   OR gender NOT IN ('F', 'M')
   OR acquisition_channel NOT IN (
       'organic',
       'paid_search',
       'partner',
       'referral',
       'social',
       'offline'
   )
   OR risk_score NOT BETWEEN 1 AND 100

UNION ALL

SELECT
    'accounts',
    'invalid_account_values',
    COUNT(*)
FROM raw.accounts
WHERE account_type NOT IN ('debit', 'current', 'savings', 'credit')
   OR currency NOT IN ('RUB', 'USD', 'EUR')
   OR status NOT IN ('active', 'blocked', 'closed')

UNION ALL

SELECT
    'cards',
    'invalid_card_values',
    COUNT(*)
FROM raw.cards
WHERE card_type NOT IN ('virtual', 'physical')
   OR payment_system NOT IN ('MIR', 'Visa', 'Mastercard')
   OR status NOT IN ('issued', 'active', 'blocked')
   OR expires_at <= issued_at

UNION ALL

SELECT
    'merchants',
    'invalid_merchant_values',
    COUNT(*)
FROM raw.merchants
WHERE risk_level NOT IN ('low', 'medium', 'high')

UNION ALL

SELECT
    'transactions',
    'invalid_transaction_values',
    COUNT(*)
FROM raw.transactions
WHERE transaction_type NOT IN (
       'card_purchase',
       'transfer',
       'cash_withdrawal',
       'cash_deposit',
       'refund'
   )
   OR currency NOT IN ('RUB', 'USD', 'EUR')
   OR status NOT IN ('completed', 'declined', 'reversed')
   OR channel NOT IN ('online', 'pos', 'web', 'atm', 'branch', 'mobile')
   OR amount <= 0
   OR fee_amount < 0

UNION ALL

SELECT
    'sessions',
    'invalid_session_values',
    COUNT(*)
FROM raw.sessions
WHERE channel NOT IN ('mobile', 'web')
   OR device_os NOT IN ('iOS', 'Android', 'Windows', 'macOS')
   OR events_count < 0

UNION ALL

SELECT
    'accounts',
    'opened_before_registration',
    COUNT(*)
FROM raw.accounts accounts
JOIN raw.customers customers
    ON customers.customer_id = accounts.customer_id
WHERE accounts.opened_at < customers.registration_ts::DATE

UNION ALL

SELECT
    'accounts',
    'closed_before_opened',
    COUNT(*)
FROM raw.accounts
WHERE closed_at < opened_at

UNION ALL

SELECT
    'cards',
    'issued_before_account_opened',
    COUNT(*)
FROM raw.cards cards
JOIN raw.accounts accounts
    ON accounts.account_id = cards.account_id
WHERE cards.issued_at < accounts.opened_at

UNION ALL

SELECT
    'cards',
    'activated_before_issued',
    COUNT(*)
FROM raw.cards
WHERE activated_at < issued_at

UNION ALL

SELECT
    'transactions',
    'transaction_before_account_opened',
    COUNT(*)
FROM raw.transactions transactions
JOIN raw.accounts accounts
    ON accounts.account_id = transactions.account_id
WHERE transactions.transaction_ts::DATE < accounts.opened_at

UNION ALL

SELECT
    'transactions',
    'transaction_before_card_issued',
    COUNT(*)
FROM raw.transactions transactions
JOIN raw.cards cards
    ON cards.card_id = transactions.card_id
WHERE transactions.transaction_ts::DATE < cards.issued_at

UNION ALL

SELECT
    'transactions',
    'card_account_mismatch',
    COUNT(*)
FROM raw.transactions transactions
JOIN raw.cards cards
    ON cards.card_id = transactions.card_id
WHERE cards.account_id <> transactions.account_id

UNION ALL

SELECT
    'transactions',
    'card_reference_missing_for_card_operation',
    COUNT(*)
FROM raw.transactions
WHERE transaction_type IN ('card_purchase', 'refund')
  AND card_id IS NULL

UNION ALL

SELECT
    'sessions',
    'ended_before_started',
    COUNT(*)
FROM raw.sessions
WHERE ended_at < started_at;

SELECT
    table_name,
    check_name,
    issue_count
FROM audit.data_quality_summary
ORDER BY table_name, check_name;
