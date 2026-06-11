-- Retail Data Analysis Project
-- SQL Queries for Sales Data Analysis

-- Phase 7: Database Setup
-- NOTE: customer_id in the CSV file contains alphanumeric values (e.g., 'CS5295'). 
-- Defining customer_id as INT will result in import failures or truncated data. 
-- It should be defined as VARCHAR(50).

-- 1. Create Database
CREATE DATABASE retail_sales;
USE retail_sales;

-- 2. Create Table
CREATE TABLE transactions (
    customer_id VARCHAR(50),
    trans_date DATE,
    tran_amount INT
);

-- 3. Import CSV Data
-- MySQL CSV Import:
-- LOAD DATA INFILE '/path/to/Retail_Data_Transactions.csv'
-- INTO TABLE transactions
-- FIELDS TERMINATED BY ','
-- OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES
-- (customer_id, @trans_date_temp, tran_amount)
-- SET trans_date = STR_TO_DATE(@trans_date_temp, '%d-%b-%y');

-- PostgreSQL CSV Import:
-- COPY transactions(customer_id, trans_date, tran_amount)
-- FROM '/path/to/Retail_Data_Transactions.csv'
-- DELIMITER ','
-- CSV HEADER;

-- SQLite CSV Import:
-- .mode csv
-- .import Retail_Data_Transactions.csv transactions


-- 4. Analytical Queries

-- Query 1: What is the total revenue?
SELECT SUM(tran_amount) AS total_revenue 
FROM transactions;

-- Query 2: What is the average transaction amount?
SELECT AVG(tran_amount) AS avg_transaction_amount 
FROM transactions;

-- Query 3: Who are the top 10 customers?
SELECT customer_id, SUM(tran_amount) AS total_spend
FROM transactions
GROUP BY customer_id
ORDER BY total_spend DESC
LIMIT 10;

-- Query 4: Which year generated the highest revenue?
-- (For MySQL/SQL Server)
SELECT YEAR(trans_date) AS revenue_year, SUM(tran_amount) AS total_revenue
FROM transactions
GROUP BY YEAR(trans_date)
ORDER BY total_revenue DESC;

-- (For PostgreSQL alternative)
-- SELECT EXTRACT(YEAR FROM trans_date) AS revenue_year, SUM(tran_amount) AS total_revenue
-- FROM transactions
-- GROUP BY EXTRACT(YEAR FROM trans_date)
-- ORDER BY total_revenue DESC;

-- (For SQLite alternative)
-- SELECT strftime('%Y', trans_date) AS revenue_year, SUM(tran_amount) AS total_revenue
-- FROM transactions
-- GROUP BY revenue_year
-- ORDER BY total_revenue DESC;

