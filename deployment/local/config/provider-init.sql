-- Create the EDC connector database (separate from IH)
CREATE DATABASE provider_edc OWNER provider;
GRANT ALL PRIVILEGES ON DATABASE provider_edc TO provider;
