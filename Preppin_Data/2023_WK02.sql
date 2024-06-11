/*
In the Transactions table, there is a Sort Code field which contains dashes. We need to remove these to just have a 6 digit string
Use the SWIFT Bank Code lookup table to bring in additional information about the SWIFT code and Check Digits of the receiving bank account
Add a field for the Country Code
Hint: all these transactions take place in the UK so the Country Code should be GB
Create the IBAN

*/

SELECT 
t.transaction_ID, 
CONCAT( 'GB', s.check_digits, s.swift_code, REPLACE( sort_code, '-' ), t.account_number ) AS IBAN 

FROM wk2_transactions AS t

JOIN wk2_swiftcodes AS s ON t.bank = s.bank;