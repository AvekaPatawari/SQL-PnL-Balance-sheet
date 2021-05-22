
-- Script to generate Income Statement and Balance Sheet
-- Enter year for the respective statement in the bottom of the script as the inout for the two procedures

USE H_Accounting;

-- Creating Procedure to generate Balance Sheet

DROP PROCEDURE IF EXISTS msandberg_balance_sheet;

DELIMITER $$

	CREATE PROCEDURE msandberg_balance_sheet(varCalendarYear YEAR)
	BEGIN
    
    -- Declaring variables for Balance Sheet items
    
		DECLARE varCurrAssets DOUBLE DEFAULT 0;
        DECLARE varCurrLiabilities DOUBLE DEFAULT 0;
        DECLARE varEquity DOUBLE DEFAULT 0;
        
	-- Calculate the values for the different balance sheet items for the given year and store it into the variables
    
		-- Current Assets

		SELECT SUM(debit) - SUM(credit) INTO varCurrAssets
			FROM journal_entry_line_item
			INNER JOIN `account` AS a USING(account_id)
			INNER JOIN statement_section AS s ON s.statement_section_id = a.balance_sheet_section_id
			INNER JOIN journal_entry AS j USING(journal_entry_id)
			WHERE YEAR(j.entry_date) = varCalendarYear
			AND j.debit_credit_balanced = 1
            AND statement_section = 'CURRENT ASSETS';
	
		-- Current Liabilities

		SELECT SUM(credit) - SUM(debit) INTO varCurrLiabilities
			FROM journal_entry_line_item
			INNER JOIN `account` AS a USING(account_id)
			INNER JOIN statement_section AS s ON s.statement_section_id = a.balance_sheet_section_id
			INNER JOIN journal_entry AS j USING(journal_entry_id)
			WHERE YEAR(j.entry_date) = varCalendarYear
			AND j.debit_credit_balanced = 1
            AND statement_section = 'CURRENT LIABILITIES';
        
		-- Equity

		SELECT (IFNULL(SUM(credit),0)) - (IFNULL(SUM(debit),0)) INTO varEquity
			FROM journal_entry_line_item
			INNER JOIN `account` AS a USING(account_id)
			INNER JOIN statement_section AS s ON s.statement_section_id = a.balance_sheet_section_id
			INNER JOIN journal_entry AS j USING(journal_entry_id)
			WHERE YEAR(j.entry_date) = varCalendarYear
			AND j.debit_credit_balanced = 1
            AND statement_section = 'EQUITY';
            
            
	-- Creating table for Balance Sheet
    
		DROP TABLE IF EXISTS tmp_msandberg2019_BS;
  
		CREATE TABLE tmp_msandberg2019_BS
		( balance_sheet_line_number INT, 
			label VARCHAR(50), 
			amount VARCHAR(50)
		);
  
	  -- Inserting the a header
	  INSERT INTO tmp_msandberg2019_BS 
			(balance_sheet_line_number, label, amount)
			VALUES (1, 'BALANCE SHEET STATEMENT', "In '000s of USD");
	  
	  -- Inserting an empty line 
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (2, '', '');
		
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (3, 'Year', varCalendarYear);
            
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (4, '', '');
    
		-- Inserting Current Assets
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (5, 'Current Assets', format(varCurrAssets / 1000, 2));
		
		-- Inserting an empty line 
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (6, '', '');
			
		-- Inserting Current Liabilities
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (7, 'Current Liabilities', format(varCurrLiabilities / 1000, 2));
		
		-- Inserting an empty line 
		INSERT INTO tmp_msandberg2019_BS 
			(balance_sheet_line_number, label, amount)
			VALUES (8, '', '');
		
		-- Inserting Equity
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (9, 'Equity', format(varEquity / 1000, 2));
		
		-- Inserting an empty line 
		INSERT INTO tmp_msandberg2019_BS 
			(balance_sheet_line_number, label, amount)
			VALUES (10, '', '');
			
		-- Inserting 'Assets - (Liabilities + Equity)' to ensure Balance Sheet is balanced
		INSERT INTO tmp_msandberg2019_BS
			(balance_sheet_line_number, label, amount)
			VALUES (11, 'Assets - (Liabilities + Equity)', format((varCurrAssets - varCurrLiabilities - varEquity) / 1000, 2));
			
	END $$

DELIMITER ;



-- Creating procedure to generate Income Statement
DROP PROCEDURE IF EXISTS msandberg_calculate_revenues_for_a_cy;

DELIMITER $$

	CREATE PROCEDURE msandberg_calculate_revenues_for_a_cy(varCalendarYear YEAR)
	BEGIN
  
	
  
	-- Declaring variables for Balance Sheet items
		DECLARE varTotalRevenues DOUBLE DEFAULT 0;
        DECLARE varTotalCOGS DOUBLE DEFAULT 0;
        DECLARE varTotalRetRefDis DOUBLE DEFAULT 0;
        DECLARE varGrossProfit DOUBLE DEFAULT 0;
        DECLARE varTotalAdminExpenses DOUBLE DEFAULT 0;
        DECLARE varTotalSellingExpenses DOUBLE DEFAULT 0;
        DECLARE varTotalOtherIncome DOUBLE DEFAULT 0;
		DECLARE varTotalOtherExpenses DOUBLE DEFAULT 0;
        DECLARE varEBIT DOUBLE DEFAULT 0;
        DECLARE varIncomeTax DOUBLE DEFAULT 0;
        DECLARE varOtherTax DOUBLE DEFAULT 0;
        DECLARE varNetProfit DOUBLE DEFAULT 0;
        
	-- Calculating the values for the different IS items for the given year and store it into the variables
        
		-- Revenue
		SELECT SUM(jeli.credit) INTO varTotalRevenues
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "REV"
				AND YEAR(je.entry_date) = varCalendarYear;                
		
        -- COGS
		SELECT SUM(jeli.debit) INTO varTotalCOGS
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "COGS"
				AND YEAR(je.entry_date) = varCalendarYear;
                
		-- Returns, Refunds, Discounts
		SELECT IFNULL( SUM(jeli.debit), 0) INTO varTotalRetRefDis
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "RET"
				AND YEAR(je.entry_date) = varCalendarYear;
		
        -- Gross Profit
		SELECT (varTotalRevenues - varTotalCOGS - varTotalRetRefDis) INTO varGrossProfit;
        
		-- Administrative Expenses
		SELECT IFNULL( SUM(jeli.debit), 0) INTO varTotalAdminExpenses
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "GEXP"
				AND YEAR(je.entry_date) = varCalendarYear;
                
		-- Selling Expenses
		SELECT SUM(jeli.debit) INTO varTotalSellingExpenses
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "SEXP"
				AND YEAR(je.entry_date) = varCalendarYear;
                
                
		-- Other Income
		SELECT IFNULL( SUM(jeli.credit), 0) INTO varTotalOtherIncome
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "OI"
				AND YEAR(je.entry_date) = varCalendarYear;
                
		-- Other Expenses
		SELECT IFNULL( SUM(jeli.debit), 0) INTO varTotalOtherExpenses
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "OEXP"
				AND YEAR(je.entry_date) = varCalendarYear;
                
		-- EBIT
		SELECT varGrossProfit - varTotalAdminExpenses - varTotalSellingExpenses + varTotalOtherIncome - varTotalOtherExpenses INTO varEBIT;

		-- Income Tax
		SELECT IFNULL( SUM(jeli.debit), 0) INTO varIncomeTax
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "INCTAX"
				AND YEAR(je.entry_date) = varCalendarYear;
                
		-- Other Tax
		SELECT IFNULL( SUM(jeli.debit), 0) INTO varOtherTax
		
			FROM journal_entry_line_item AS jeli
		
				INNER JOIN account 						AS ac ON ac.account_id = jeli.account_id
				INNER JOIN journal_entry 			AS je ON je.journal_entry_id = jeli.journal_entry_id
				INNER JOIN statement_section	AS ss ON ss.statement_section_id = ac.profit_loss_section_id
      
			WHERE ss.statement_section_code = "OTHTAX"
				AND YEAR(je.entry_date) = varCalendarYear;
                
		-- Net Profit
		SELECT varEBIT - varIncomeTax - varOtherTax INTO varNetProfit;
        

	-- Creating table for Income Statement
		DROP TABLE IF EXISTS tmp_msandberg2019_table;
  
	-- Creating columns
		CREATE TABLE tmp_msandberg2019_table
		( profit_loss_line_number INT, 
			label VARCHAR(50), 
			amount VARCHAR(50)
		);
  
		-- Inserting the a header
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (1, 'PROFIT AND LOSS STATEMENT', "In '000s of USD");
	  
		-- Inserting an empty line
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (2, '', '');
	
		-- Inserting Year
		INSERT INTO tmp_msandberg2019_table
			(profit_loss_line_number, label, amount)
			VALUES (3, 'Year', varCalendarYear);
            
		  -- Inserting an empty line
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (4, '', '');
		
		-- Inserting Total Revenues
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (5, 'Total Revenues', format(varTotalRevenues / 1000, 2));
		
		-- Inserting COGS
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (6, 'COGS', format(varTotalCOGS / 1000, 2));
			
		-- Inserting Returns, Refunds, Discounts
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (7, 'Returns, Refunds, Discounts', format(varTotalRetRefDis / 1000, 2));
			
		-- Inserting Gross Profit
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (8, 'Gross Profit', format(varGrossProfit / 1000, 2));
		
		-- Next we insert an empty line to create some space between the header and the line items
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (9, '', '');
		
		-- Inserting Administrative Expenses
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (10, 'Administrative Expenses', format(varTotalAdminExpenses / 1000, 2));

		-- Inserting Selling Expenses
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (11, 'Selling Expenses', format(varTotalSellingExpenses / 1000, 2));
			
		-- Inserting Other Income
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (12, 'Other Income', format(varTotalOtherIncome / 1000, 2));
			
		-- Inserting Other Expenses
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (13, 'Other Expenses', format(varTotalOtherExpenses / 1000, 2));
			
		-- Inserting EBIT
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (14, 'Earnings before interest and tax (EBIT)', format(varEBIT / 1000, 2));

		-- Next we insert an empty line to create some space between the header and the line items
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (15, '', '');
			
		-- Inserting Income Tax
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (16, 'Income Tax', format(varIncomeTax / 1000, 2));
			
		-- Inserting Other Tax
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (17, 'Other Tax', format(varOtherTax / 1000, 2));

		-- Inserting Net Profit
		INSERT INTO tmp_msandberg2019_table 
			(profit_loss_line_number, label, amount)
			VALUES (18, 'Net Profit', format(varNetProfit / 1000, 2));
		
	END $$

DELIMITER ;

CALL msandberg_calculate_revenues_for_a_cy(2016);
CALL msandberg_balance_sheet(2016);

SELECT * FROM tmp_msandberg2019_BS;
SELECT * FROM tmp_msandberg2019_table;