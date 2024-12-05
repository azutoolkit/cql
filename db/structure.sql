-- Table: customers

-- Primary Key: id - Type: Int64 

CREATE TABLE IF NOT EXISTS customers (customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, customer_name VARCHAR NOT NULL, city VARCHAR NOT NULL, country_id BIGINT NOT NULL, id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY)


-- Table: countries

-- Primary Key: id - Type: Int64 

CREATE TABLE IF NOT EXISTS countries (id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, country VARCHAR NOT NULL)


-- Table: user_pref

-- Primary Key: id - Type: Int64 

CREATE TABLE IF NOT EXISTS user_pref (id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, preferences JSONB NOT NULL)

