-- Create the ccmbi schema
CREATE SCHEMA IF NOT EXISTS ccmbi;

-- Update search_path for the current user and postgres
ALTER ROLE ccmbi SET search_path TO ccmbi, "$user", postgres;

-- Create the extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS http;

-- Optionally, set a default search_path for the database
ALTER DATABASE ccmbi SET search_path TO ccmbi, "$user", postgres;
