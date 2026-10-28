CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id TEXT,
    registration_ts TIMESTAMP,
    birth_date DATE,
    gender TEXT,
    region TEXT,
    acquisition_channel TEXT,
    income_band TEXT,
    risk_score INTEGER,
    is_premium BOOLEAN,
    first_name TEXT,
    last_name TEXT
);

CREATE TABLE IF NOT EXISTS raw.accounts (
    account_id TEXT,
    customer_id TEXT,
    opened_at DATE,
    closed_at DATE,
    account_type TEXT,
    currency TEXT,
    status TEXT,
    current_balance NUMERIC(14, 2)
);

CREATE TABLE IF NOT EXISTS raw.cards (
    card_id TEXT,
    account_id TEXT,
    issued_at DATE,
    activated_at DATE,
    card_type TEXT,
    payment_system TEXT,
    status TEXT,
    expires_at DATE
);

CREATE TABLE IF NOT EXISTS raw.merchants (
    merchant_id TEXT,
    merchant_name TEXT,
    category TEXT,
    city TEXT,
    country TEXT,
    risk_level TEXT
);

CREATE TABLE IF NOT EXISTS raw.transactions (
    transaction_id TEXT,
    account_id TEXT,
    card_id TEXT,
    merchant_id TEXT,
    transaction_ts TIMESTAMP,
    transaction_type TEXT,
    amount NUMERIC(14, 2),
    currency TEXT,
    fee_amount NUMERIC(14, 2),
    status TEXT,
    channel TEXT
);

CREATE TABLE IF NOT EXISTS raw.sessions (
    session_id TEXT,
    customer_id TEXT,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    channel TEXT,
    device_os TEXT,
    events_count INTEGER,
    auth_success BOOLEAN
);
