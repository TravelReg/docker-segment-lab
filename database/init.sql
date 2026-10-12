CREATE TABLE IF NOT EXISTS network_events (
    id BIGSERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO network_events (message)
VALUES ('Database initialized inside segment_data');
