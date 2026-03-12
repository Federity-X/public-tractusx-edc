-- Create the EDC connector database (separate from IH)
CREATE DATABASE consumer_edc OWNER consumer;
GRANT ALL PRIVILEGES ON DATABASE consumer_edc TO consumer;
