/* 1) Calculate the total sales amount (AMOUNT_SOLD) for each product category 
    (PROD_CATEGORY) in each calendar year (CALENDAR_YEAR), including only 
    products whose standard cost (PROD_STANDARD_COST) is higher than the average
    standard cost of all products.
*/

SELECT
    p.PROD_CATEGORY,
    t.CALENDAR_YEAR,
    SUM(s.AMOUNT_SOLD) AS TotalSalesAmount
FROM SH.SALES s
INNER JOIN SH.PRODUCTS p ON s.PROD_ID = p.PROD_ID
INNER JOIN SH.TIMES t ON s.TIME_ID = t.TIME_ID
WHERE p.PROD_LIST_PRICE > (SELECT AVG(PROD_LIST_PRICE) FROM SH.PRODUCTS)
GROUP BY p.PROD_CATEGORY, t.CALENDAR_YEAR
ORDER BY t.CALENDAR_YEAR, p.PROD_CATEGORY;
    

/* 2) Find the top 3 customers with the highest total sales in each country 
    (COUNTRY_NAME). View the customer's country, ID, total sales amount,
    and ranking in that country.
*/

SELECT * FROM (
    SELECT c.cust_id, ct.country_name,
        sum(s.quantity_sold * s.amount_sold) as amount_sold,
        RANK() OVER (PARTITION BY ct.country_name 
            order by sum(s.quantity_sold * s.amount_sold) desc) as rn
    FROM Sales s
    INNER JOIN customers c on c.cust_id = s.cust_id
    INNER JOIN countries ct on c.country_id = ct.country_id
    GROUP BY c.cust_id, ct.country_name
) WHERE rn <= 3;


/* 3) Show the total sales amount (AMOUNT_SOLD) for each calendar year 
    (CALENDAR_YEAR), broken down by sales channel (CHANNEL_DESC) as columns.
*/

SELECT * FROM (
    SELECT c.channel_desc, t.calendar_year, amount_sold
    FROM Sales s
    INNER JOIN TIMES t on s.time_id = t.time_id
    INNER JOIN CHANNELS c on s.channel_id = c.channel_id
) PIVOT (
    SUM(AMOUNT_SOLD) 
    FOR CHANNEL_DESC IN (
        'Internet' AS Internet, 
        'Direct Sales' AS Direct_Sales,
        'Partners' AS Partners,
        'Telesales' AS Telesales,
        'Catalog' AS Catalog
    )
)
ORDER BY CALENDAR_YEAR;
    

/* 4) Assign each customer in a given calendar year a category 
    ('High Value', 'Medium Value', 'Low Value') based on their total sales
    amount for that year.
*/

SELECT s.cust_id, t.calendar_year, sum(amount_sold) total_amount,
    CASE
        WHEN sum(amount_sold) < 2000 THEN 'Low Value'
        WHEN sum(amount_sold) < 10000 THEN 'Medium Value'
        ELSE 'High Value'
    END AS category
FROM Sales s
INNER JOIN Times t on s.time_id = t.time_id
GROUP BY s.cust_id, t.calendar_year
ORDER BY
    t.CALENDAR_YEAR,
    total_amount DESC;


/* 5) Calculate the 3-month rolling average of the total sales amount (AMOUNT_SOLD)
    for each calendar month
*/

SELECT year, month, total,
    cast(avg(total) over (
        order by year, month 
        rows between 2 preceding and current row
      ) 
      as decimal(11,2)
    ) 
FROM (
    SELECT extract(year from time_id) as year,
        extract(month from time_id) month,
        sum(amount_sold) total
    FROM Sales
    GROUP BY extract(year from time_id), extract(month from time_id)
);


/* 6) For each customer (CUST_ID), find the date (TIME_ID) and 
    amount (AMOUNT_SOLD) of their first sale.
*/

SELECT cust_id, time_id, amount_sold FROM (
    SELECT cust_id, time_id, sum(amount_sold) amount_sold, 
        rank() over (partition by cust_id order by time_id) as rnk 
    FROM Sales
    GROUP BY cust_id, time_id
) WHERE rnk = 1;


/* 7) Analysis of the percentage change in sales month over month.

    Calculate the total sales amount for each month and compare it to the previous
    month's total sales amount by calculating the percentage change.
*/

SELECT year, month, total, prev_mth_total, 
    case
        when prev_mth_total is null then '+0'
        when round(((total - prev_mth_total) / prev_mth_total) * 100, 2) < -1 then
            cast(round(((total - prev_mth_total) / prev_mth_total) * 100, 2) as varchar2(6))
        when round(((total - prev_mth_total) / prev_mth_total) * 100, 2) between -1 and 0 then
            replace(cast(round(((total - prev_mth_total) / prev_mth_total) * 100, 2) as varchar2(6)), 
                '-,', '-0,' 
            )
        when round(((total - prev_mth_total) / prev_mth_total) * 100, 2) between 0 and 1 then
            replace(cast(round(((total - prev_mth_total) / prev_mth_total) * 100, 2) as varchar2(6)), 
                ',', '+0,' 
            )
        else '+' || cast(round(((total - prev_mth_total) / prev_mth_total) * 100, 2) as varchar2(6))
    end as percentage
FROM (
    SELECT extract(year from time_id) as year,
           extract(month from time_id) month,
           sum(amount_sold) total,
           lag(sum(amount_sold)) over (
                order by extract(year from time_id), extract(month from time_id)
           ) prev_mth_total
    FROM Sales
    GROUP BY extract(year from time_id), extract(month from time_id)
);


/* 8) For each product, enter the name of the product and the total amount sold,
    but only if the total sales of that product are higher than the average sales
    of all products in the same year that the product was sold.
*/

WITH cte AS (
    SELECT prod_id, extract(year from time_id) as year, 
        sum(amount_sold) as total_sum
    FROM Sales s1
    GROUP BY prod_id, extract(year from time_id)
)
SELECT p.prod_name, year, total_sum FROM cte c1
INNER JOIN PRODUCTS p on c1.prod_id = p.prod_id
WHERE TOTAL_SUM > (
    SELECT AVG(TOTAL_SUM) FROM cte c2
    WHERE c1.year = c2.year
) ORDER BY YEAR, TOTAL_SUM;


/* 9) Generate a sequence of months for a given year and calculate the cumulative
    sales amount month by month in this year.
*/

SELECT time_id, total_amount,
    sum(total_amount) over (partition by substr(time_id, 1, 4) order by time_id) as step_sum 
FROM (
    SELECT to_char(time_id, 'yyyymm') TIME_ID, sum(amount_sold) total_amount
    FROM Sales
    GROUP BY to_char(time_id, 'yyyymm')
);


/* 10) Calculate the total sales amount for each calendar month in the year 2020
    and determine the cumulative (growing) sales amount from the beginning of the year
    to the end of each month using a recursive CTE.
*/

WITH rank_time AS (
    SELECT
        TO_CHAR(time_id, 'yyyymm') AS time_id,
        SUM(amount_sold) AS amount_sold,
        DENSE_RANK() OVER (ORDER BY TO_CHAR(time_id, 'yyyymm')) AS drnk
    FROM Sales
    WHERE EXTRACT(YEAR FROM time_id) = 2020
    GROUP BY TO_CHAR(time_id, 'yyyymm')
), recursive (time_id, amount_sold, total_sold, drnk) AS (
    SELECT 
        rt1.time_id, rt1.amount_sold, rt1.amount_sold AS total_sold, rt1.drnk
    FROM rank_time rt1
    WHERE rt1.drnk = 1
    UNION ALL
    SELECT
        rt2.time_id, rt2.amount_sold,
        rcsv.total_sold + rt2.amount_sold AS total_sold,
        rt2.drnk
    FROM rank_time rt2
    INNER JOIN recursive rcsv ON rt2.drnk = rcsv.drnk + 1
)
SELECT time_id, amount_sold AS monthly_sales, total_sold
FROM recursive
ORDER BY drnk;


/* 11) Generate a list of all months from January 2020 to December 2021
    (even if there were no sales in them) and display the total sales for
    each of those months, using a recursive CTE to generate a sequence of dates.
*/

WITH dates AS (
    SELECT to_char(add_months(to_date('20200101', 'yyyymmdd'), level - 1), 'yyyymm') time_id
    FROM DUAL CONNECT BY LEVEL <= 24
), rank_time AS (
    SELECT
        d.time_id,
        nvl(SUM(amount_sold), 0) AS amount_sold,
        DENSE_RANK() OVER (ORDER BY d.time_id) AS drnk
    FROM Sales s
    FULL JOIN dates d on to_char(s.time_id, 'yyyymm') = d.time_id
    WHERE EXTRACT(YEAR FROM s.time_id) in (2020, 2021)
    GROUP BY d.time_id
), recursive (time_id, amount_sold, total_sold, drnk) AS (
    SELECT 
        rt1.time_id, rt1.amount_sold, rt1.amount_sold AS total_sold, rt1.drnk
    FROM rank_time rt1
    WHERE rt1.drnk = 1
    UNION ALL
    SELECT
        rt2.time_id, rt2.amount_sold,
        /*CASE mod(rt2.drnk, 12)
            WHEN 1 then rt2.amount_sold
            ELSE rcsv.total_sold + rt2.amount_sold 
        END AS total_sold,*/
        CASE SUBSTR(rt2.TIME_ID, 5, 2)
            WHEN '01' then rt2.amount_sold
            ELSE rcsv.total_sold + rt2.amount_sold 
        END AS total_sold,
        rt2.drnk
    FROM rank_time rt2
    INNER JOIN recursive rcsv ON rt2.drnk = rcsv.drnk + 1
)
SELECT time_id, amount_sold AS monthly_sales, total_sold
FROM recursive
ORDER BY drnk;


/* 12) For each sales channel and month (from the TIMES table), display the total
    sales costs (from the COSTS table), sorted by cost in descending order. 
    Add a column with the channel ranking for the month (ranking by cost). 
    Include only the last year available in the data.
*/

SELECT t.calendar_month_number, c.channel_id, 
    sum(unit_price) total_price,
    DENSE_RANK() OVER (PARTITION BY t.calendar_month_number ORDER BY sum(unit_price) DESC) AS RANK
FROM Costs c
INNER JOIN Times t on c.time_id = c.time_id
WHERE t.calendar_year = (SELECT max(extract(year from time_id)) FROM costs)
GROUP BY t.calendar_month_number, c.channel_id;


/* 13) Determine the Top 3 sales channels (channel_desc) that generate the 
    highest average monthly gross profit (gross amount – cost amount), 
    broken down by year. The result should include: year, channel_desc, 
    average monthly gross profit, and ranking position.
*/

SELECT * FROM (
    SELECT 
        t.calendar_year,
        c.channel_desc,
        ROUND(AVG(s.amount_sold * p.prod_list_price - s.amount_sold * p.prod_min_price), 2) AS avg_monthly_profit,
        RANK() OVER (PARTITION BY t.calendar_year ORDER BY 
                     AVG(s.amount_sold * p.prod_list_price - s.amount_sold * p.prod_min_price) DESC) AS rank_channel
    FROM sales s
    INNER JOIN products p ON s.prod_id = p.prod_id
    INNER JOIN times t ON s.time_id = t.time_id
    INNER JOIN channels c ON s.channel_id = c.channel_id
    GROUP BY t.calendar_year, c.channel_desc
)
WHERE rank_channel <= 3
ORDER BY calendar_year, rank_channel;


/* 14) Write an SQL query that:
    - Joins data from at least three tables: SALES, TIMES AND CUSTOMERS
    - Limits the results to sales in 2019 (from January 1, 2019 to December 31, 2019).
    - Based on the combined data, calculates the total value of sales for each
    quarter of 2019. Use the aggregate function SUM(AMOUNT_SOLD).
    
    The results will be presented in the form of a pivot – the rows will represent
    regions, and the columns will correspond to quarters: Q1, Q2, Q3, Q4.
*/

SELECT cust_id, cust_first_name, cust_last_name, 
    nvl(q1, 0) q1, nvl(q2, 0) q2, nvl(q3, 0) q3, nvl(q4, 0) q4 
FROM (
    SELECT c.cust_id, c.cust_first_name, c.cust_last_name, 
        'Q' || to_char(t.calendar_quarter_number) as quarter, s.amount_sold
    FROM Sales s
    INNER JOIN Customers c on s.cust_id = c.cust_id
    INNER JOIN Times t on s.time_id = t.time_id
) PIVOT (
    SUM(amount_sold) FOR quarter in ('Q1' as q1, 'Q2' as q2, 'Q3' as q3, 'Q4' as q4)
);


/* 15) Which countries on each continent spend the most on shopping in particular year? 
    View country, continent, year and total amount
*/

SELECT country_name, country_region, YEAR, TOTAL_AMOUNT FROM (
    SELECT cn.country_name, cn.country_region,
        extract(year from s.time_id) year, SUM(s.amount_sold) TOTAL_AMOUNT,
        RANK() OVER (PARTITION BY extract(year from s.time_id), cn.country_region 
            ORDER BY SUM(s.amount_sold) DESC
        ) RNK
    FROM Sales s
    INNER JOIN Customers c on s.cust_id = c.cust_id
    INNER JOIN Countries cn on c.country_id = cn.country_id
    GROUP BY cn.country_name, cn.country_region, extract(year from s.time_id)
) WHERE RNK = 1;