/* 1) check nationality of customers */

select c.customer_id, 
    case
        when substr(c.address, instr(c.address, ',', 1, 1) + 2,  
            instr(c.address, ',', 1, 2) - instr(c.address, ',', 1, 1) - 2)
            like '%India%' then 'India'
        else substr(c.address, instr(c.address, ',', 1, 2) + 2) 
    end as country, cn.country_name, cn.country_id
from Customers c
left join countries cn 
    on (case
        when substr(c.address, instr(c.address, ',', 1, 1) + 2,  
            instr(c.address, ',', 1, 2) - instr(c.address, ',', 1, 1) - 2)
            like '%India%' then 'India'
        else substr(c.address, instr(c.address, ',', 1, 2) + 2) 
        end) = any(cn.country_id, cn.country_name);

        
/* 2) who sold the most of products (sum of quantity) (first name and last name) */

select any_value(e.first_name), any_value(e.last_name)
from employees e
inner join orders o on o.salesman_id = e.employee_id
left join order_items oi on o.order_id = oi.order_id
group by o.salesman_id
order by SUM(oi.quantity) desc 
fetch first 1 row only;

/* 3) return total sums of partitcular products:
        in partitcular warehouses
        summary (group by product_id)
        summary (all products in all warehouses)
   print product name, warehouse name, and sum(quantity)

   WARNING: products can have a few product_id
*/

select 
    CASE GROUPING_ID(i.product_id, i.warehouse_id)
    WHEN 0 THEN 'Quanity of product: ' || cast(i.product_id as varchar2(200)) 
        || '(' || any_value(p.product_name) || ')'
        || ' in warehouse: ' || cast(i.warehouse_id as varchar2(200))
        || '(' || any_value(w.warehouse_name) || ')'
    WHEN 1 THEN 'Quanity of product: ' || cast(i.product_id as varchar2(200))
        || '(' || any_value(p.product_name) || ')'
        || ' in all warehouses'
    WHEN 2 THEN 'Total Quanity in warehouse: ' || cast(i.warehouse_id as varchar2(200))
        || '(' || any_value(w.warehouse_name) || ')'
    ELSE 'Total Quantity in all warehouses'
    END AS sum_describe,
    sum(i.quantity) sum_quantity
from inventories i
left join products p on i.product_id = p.product_id
left join warehouses w on i.warehouse_id = w.warehouse_id
group by cube(i.product_id, i.warehouse_id);


/* 4) Find the 5 customers who placed the most orders in 2017. 
   View their names and number of orders.
*/

select any_value(c.name) customer
from customers c 
inner join Orders o on c.customer_id = o.customer_id
where extract(year from o.order_date) = 2017
group by o.customer_id
order by count(*) desc, o.customer_id
fetch first 5 rows only;


/* 5) Display a list of employees (name, surname) who processed orders with a total
   value above 100000. Sort the results descending by order value.
*/

select e.first_name,e.last_name
from employees e
inner join orders o on o.salesman_id = e.employee_id
inner join order_items oi on o.order_id = oi.order_id
group by o.salesman_id, e.first_name, e.last_name
having sum(oi.quantity * oi.unit_price) > 100000
ORDER BY SUM(oi.unit_price * oi.quantity) DESC;

/* 6) For each product, display its name, average unit price across orders, 
    and total units sold. Show only products whose average unit price is higher 
    than the average price of all products.
*/

select p.product_name, avg(oi.unit_price) average_price, sum(oi.quantity) total_quantity
from products p
inner join order_items oi on oi.product_id = p.product_id
group by p.product_name
having avg(oi.unit_price) > (select avg(unit_price) from order_items)
ORDER BY average_price DESC;


/* 7) Find customers who have placed orders for all products in the "CPU" category.
Display customer names.

Find customers who have not non-ordered CPU product
*/

SELECT c.name
FROM customers c
WHERE NOT EXISTS (
    /* Non-Ordered Products CPU*/
    SELECT p.product_id
    FROM products p
    WHERE p.category_id = (SELECT category_id FROM product_categories WHERE category_name = 'CPU')
    AND NOT EXISTS (
        /* Finding all ordered products*/
        SELECT oi.product_id
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        WHERE o.customer_id = c.customer_id
        AND oi.product_id = p.product_id
    )
);


/* 8) Display a list of warehouses that have products with a total value of (purchase price * quantity)
above 10000000. Show the warehouse name and total value of products.
*/

select w.warehouse_name, sum(i.quantity * p.list_price) total_value
from warehouses w
inner join inventories i on w.warehouse_id = i.warehouse_id
inner join products p on i.product_id = p.product_id
group by w.warehouse_name
having sum(i.quantity * p.list_price) > 10000000
order by total_value desc;

/* 9) Find employees who have processed orders for customers in the same country as the warehouse.
View employee first name and last name
*/

-- nationality customers
with nat_cust as (
    select c.customer_id, 
        case
            when substr(c.address, instr(c.address, ',', 1, 1) + 2,  
                instr(c.address, ',', 1, 2) - instr(c.address, ',', 1, 1) - 2)
                like '%India%' then 'India'
            else substr(c.address, instr(c.address, ',', 1, 2) + 2) 
        end as country, cn.country_name, cn.country_id
    from Customers c
    left join countries cn 
        on (case
            when substr(c.address, instr(c.address, ',', 1, 1) + 2,  
                instr(c.address, ',', 1, 2) - instr(c.address, ',', 1, 1) - 2)
                like '%India%' then 'India'
            else substr(c.address, instr(c.address, ',', 1, 2) + 2) 
            end) = any(cn.country_id, cn.country_name)
), 
nat_war as (
    -- nationality of warehouses
    select w.warehouse_id, w.warehouse_name, c.country_id, country_name from warehouses w
    inner join locations l on w.location_id = l.location_id
    inner join countries c on l.country_id = c.country_id
)
select first_name, last_name from employees e 
where exists (
    select 1 from orders o
    inner join order_items oi on o.order_id = oi.order_id
    inner join nat_cust nc on nc.customer_id = o.customer_id
    inner join inventories i on i.product_id = oi.product_id
    inner join nat_war nw on i.warehouse_id = nw.warehouse_id
    where e.employee_id = o.salesman_id and nc.country = nw.country_name
);


/* 10) View a list of the names of your employees and the number of orders
    that they have processed, if that number is greater than the average
    number of orders that have been handled by all your employees. Sort the
    results descending by the number of orders.
*/

with tot_ord as(
    select salesman_id, any_value(e.first_name) first_name,
        any_value(e.last_name) last_name,
        count(*) total_orders 
    from orders o
    inner join employees e on o.salesman_id = e.employee_id
    group by salesman_id
) 
select first_name, last_name, total_orders
from tot_ord
where total_orders > (select avg(total_orders) from tot_ord);


/* 11) Which product was most frequently ordered in each warehouse? (CTE, RANK, JOIN)
    For each warehouse, display its name and the name of the most frequently
    ordered product (if there are several - show all).
*/

with cte as (
    select w.warehouse_name, p.product_name, count(oi.quantity) total_orders
    from warehouses w
    inner join inventories i on w.warehouse_id = i.warehouse_id
    inner join products p on i.product_id = p.product_id
    inner join order_items oi on i.product_id = oi.product_id
    group by w.warehouse_name, p.product_name
),
ranking as (
    select warehouse_name, product_name, total_orders,
    rank() over (partition by warehouse_name order by cte.total_orders desc) as rnk
    from cte
)
select warehouse_name, product_name, total_orders from ranking 
where rnk = 1;


/* 12) Assign customers to quartiles (4 groups) based on the number of orders placed.
    Display customer name, number of orders and quartile number.
*/

select c.name, count(o.order_id) total_orders,
    ntile(4) over (order by count(o.order_id) desc) as "GROUP"
from customers c
left join orders o on c.customer_id = o.customer_id
group by c.name;


/* 13) Compare order value to average of last 3 orders for this customer
    (CTE, AVG, WINDOW, RANGE)

    For each order, display its value and the average value of last 3 orders
    for this customer (including the current one).
*/

with cte as (
    -- get total cost of every order 
    select o.customer_id, o.order_id, o.order_date, 
        sum(oi.quantity * oi.unit_price) product_cost
    from orders o
    inner join order_items oi on o.order_id = oi.order_id
    group by o.customer_id, o.order_id, o.order_date
)
select cte.*, 
    avg(product_cost) over (
        partition by customer_id order by customer_id, order_date
        rows between 2 preceding and current row
    ) avg_from_2_preceding_orders
from cte;


/*  14) Order Status vs. Median Order Value for a given month (CASE, MEDIAN, CTE, JOIN)
    Display the order number, date, order value, and whether the order
    value is above, below, or equal to the median order value for a given month.
*/

with cte as(
    select o.order_id, o.order_date,
        sum(oi.quantity * oi.unit_price) order_value
    from orders o
    inner join order_items oi on o.order_id = oi.order_id
    group by o.order_id, o.order_date
)
select cte.*,
    case 
        when order_value > median(cte.order_value) over (partition by to_char(cte.order_date, 'YYYYMM'))
            then 'Above'
        when order_value < median(cte.order_value) over (partition by to_char(cte.order_date, 'YYYYMM'))
            then 'Below'
        else 'Equal'
    end as compare_to_median
from cte
order by order_date;


/* 15) Find the products that have been sold the most in total and 
    which have the most in stock in each wherehouse. Display id, name,
    total quantity and info where is the most of its. 
*/

select inv.product_id, p.product_name, inv.total_quantity, inv.the_most_of
from products p
inner join (
    select product_id, total_quantity, the_most_of 
    from (
        select product_id, sum(quantity) total_quantity, 
            rank() over (order by sum(quantity) desc) rnk,
            'THE MOST SOLD' the_most_of
        from order_items
        group by product_id
    ) where rnk = 1
    union all
    select product_id, quantity, 
        'THE MOST IN WAREHOUSE ' || cast(warehouse_id as varchar2(1))
    from inventories i
    where exists(
        select warehouse_id, max(quantity)
        from inventories iq
        where i.warehouse_id = iq.warehouse_id
        group by warehouse_id
        having i.quantity = max(iq.quantity)
    )
) inv on p.product_id = inv.product_id; 


/*  16) Display the name of the employee who has the most direct reports of employees */

select first_name, last_name from employees man
where employee_id in (
    select manager_id
    from employees emp
    group by manager_id
    order by count(*) desc
    fetch first 1 row only
);


/* 17) Present the employee hierarchy for programmers 
    (from programmers to President)
    Display first name and last name employee and first name and last name of manager.
*/

select
    first_name || ' ' || last_name, 
    prior employee_id, 
    lpad(' ', 4 * (level - 1)) || prior first_name || ' ' || prior last_name as manager_name
from employees 
start with job_title = 'Programmer'
connect by nocycle prior manager_id = employee_id
order siblings by employee_id;


/* 18) return hierarchy of employee, who saled the most pieces of 
    the most expensive product (from salesman to President)
    display first and last name of employee and hierarcy level
*/

select 
    first_name || ' ' || last_name as employee_hierarchy, level as hierarchy_level
from employees 
start with employee_id = (
    select salesman_id from (
        select o.salesman_id,
            rank() over (order by sum(oi.quantity) desc) rnk
        from orders o
        inner join order_items oi on o.order_id = oi.order_id
        where product_id = 
        (
            select product_id from (
                select product_id, list_price, max(list_price) over () as max_price from products
            ) where list_price = max_price
        ) group by o.salesman_id
    ) where rnk = 1
)
connect by nocycle prior manager_id = employee_id
order siblings by employee_id;


/* 19) How has order cancellation changed over the years? By what percentage
    compared to the previous year
*/

select order_year, canceled, 
case 
    when canceled_ly >= canceled 
        then '-' || cast(round(canceled * 100 / canceled_ly, 2) as varchar2(7))
    when canceled_ly < canceled 
        then '+' || cast(round(canceled * 100 / canceled_ly, 2) as varchar2(7))
end as percent_change_prev_year from (
    select extract(year from order_date) order_year, count(*) canceled, 
        lag(count(*)) over (order by extract(year from order_date)) canceled_ly
    from orders
    where status = 'Canceled'
    group by extract(year from order_date)
);


/* 20) For the customer who most often shops, make a 5% discount on all goods. 
    And for all customers - a 10% discount on the worst-selling product
    (the lowest total quantity of sold product).
    Next, count the rolling totals of each order. 
*/

with customer_rank as (
    select customer_id,
    	rank() over (order by count(*) desc) rnk 
    from orders
    group by customer_id
), selling_rank as (
    select product_id, 
        rank() over (order by sum(quantity)) rnk
    from order_items
    group by product_id
)
select oi.order_id, oi.item_id, oi.product_id,
    case 
        when sr.rnk = 1 then oi.unit_price * 0.9
        when cr.rnk = 1 then oi.unit_price * 0.95
        else oi.unit_price
    end as unit_price_sales,
    sum (
        case 
            when sr.rnk = 1 then oi.unit_price * 0.9 * quantity
            when cr.rnk = 1 then oi.unit_price * 0.95 * quantity
            else oi.unit_price * quantity
        end
    ) over (partition by oi.order_id order by item_id 
        rows between unbounded preceding and current row
    ) as rolling_total_price
from order_items oi
inner join orders o on o.order_id = oi.order_id
left join customer_rank cr on o.customer_id = cr.customer_id
left join selling_rank sr on oi.product_id = sr.product_id;


/* 21) Make a bonus for every employee.
    a) if total order price is between 10000 and 100000 you get 50$
    b) if total order price is between 100000 and 1000000 you get 100$
    c) if total order price is greater than 1000000 you get $250
    d) bonus is the average of received amounts.
    e) present, how in every month changed any salary of particular saller
*/

-- if not exists column salary
alter table employees add salary number(5);

update employees e1
set e1.salary = (
    select
        case job_title
            when 'President' then 8000
            when 'Public Accountant' then 6000 - x
            when 'Administration Assistant' then 6500 - x
            when 'Administration Vice President' then 6800 - x
            when 'Accountant' then 6000 - x
            when 'Finance Manager' then 6000 - x
            when 'Human Resources Representative' then 6000 - x
            when 'Programmer' then 6800 - x
            when 'Marketing Manager' then 6900 - x
            when 'Marketing Representative' then 6300 - x
            when 'Public Relations Representative' then 6000 - x
            when 'Purchasing Clerk' then 5700 - x
            when 'Purchasing Manager' then 6400 - x
            when 'Sales Manager' then 6350 - x
            when 'Sales Representative' then 6450 - x
            when 'Shipping Clerk' then 6250 - x
            when 'Stock Clerk' then 6250 - x
            when 'Stock Manager' then 6600 - x
            when 'Accounting Manager' then 6900 - x
        end as salary
    from (
        select employee_id, job_title, 
            employee_id * (extract(year from current_date) - extract(year from hire_date)) as x
        from employees
    ) e2 where e1.employee_id = e2.employee_id
);
/
commit;

WITH years AS (
    SELECT '2015' AS y FROM dual UNION ALL 
    SELECT '2016' FROM dual UNION ALL 
    SELECT '2017' FROM dual
),
months AS (
    SELECT LEVEL AS m FROM dual CONNECT BY LEVEL <= 12
),
dates AS (
    SELECT 
        e.employee_id,
        e.salary,
        TO_CHAR(TO_DATE(y || LPAD(m, 2, '0'), 'YYYYMM'), 'YYYYMM') AS ym
    FROM years, months, employees e
),
order_bonuses AS (
    SELECT 
        o.salesman_id,
        TO_CHAR(o.order_date, 'YYYYMM') AS ym,
        CASE 
            WHEN SUM(oi.unit_price * oi.quantity) < 10000 THEN 0
            WHEN SUM(oi.unit_price * oi.quantity) <= 100000 THEN 50
            WHEN SUM(oi.unit_price * oi.quantity) <= 1000000 THEN 100
            ELSE 250
        END AS bonus
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.salesman_id, TO_CHAR(o.order_date, 'YYYYMM')
),
combined AS (
    SELECT 
        d.employee_id,
        d.ym,
        d.salary,
        ob.bonus
    FROM dates d
    INNER JOIN order_bonuses ob 
        ON d.employee_id = ob.salesman_id AND d.ym = ob.ym
)
SELECT 
    employee_id,
    ym AS order_month,
    salary,
    ROUND(AVG(NVL(bonus, 0)), 2) AS avg_bonus,
    salary + ROUND(AVG(NVL(bonus, 0)), 2) AS after_bonus
FROM combined
GROUP BY employee_id, salary, ym
ORDER BY employee_id, ym;


/* 22) Present the percentage of products sold in each year, broken down by product category.
    The calculation is to be based on the total number of products sold in a given year.
    For each category, determine the percentage of sales of that category out of all
    units sold in a year.
*/

select category_name,
    case when sum(r2013) over () = 0 then 0 else round(r2013 * 100/ sum(r2013) over (), 2) end as r2013,
    case when sum(r2014) over () = 0 then 0 else round(r2014 * 100/ sum(r2014) over (), 2) end as r2014,
    case when sum(r2015) over () = 0 then 0 else round(r2015 * 100/ sum(r2015) over (), 2) end as r2015,
    case when sum(r2016) over () = 0 then 0 else round(r2016 * 100/ sum(r2016) over (), 2) end as r2016,
    case when sum(r2017) over () = 0 then 0 else round(r2017 * 100/ sum(r2017) over (), 2) end as r2017
from (
    select pc.category_name, 
        nvl(sum(case when extract(year from o.order_date) = 2013 then quantity end), 0) as r2013,
        nvl(sum(case when extract(year from o.order_date) = 2014 then quantity end), 0) as r2014,
        nvl(sum(case when extract(year from o.order_date) = 2015 then quantity end), 0) as r2015,
        nvl(sum(case when extract(year from o.order_date) = 2016 then quantity end), 0) as r2016,
        nvl(sum(case when extract(year from o.order_date) = 2017 then quantity end), 0) as r2017
    from order_items oi
    left join orders o on oi.order_id = o.order_id
    left join products p on p.product_id = oi.product_id
    left join product_categories pc on p.category_id = pc.category_id
    group by category_name
);


/* 23) Provide the percentage of orders that contain products in a given category for each year.
    The calculation is to be based on the total number of orders in a given year.
    For each product category, indicate how many percent of all orders in a given year
    were orders containing at least one product from that category.
*/

select category_name,
    case when sum(r2013) over () = 0 then 0 else round(r2013 * 100/ sum(r2013) over (), 2) end as r2013,
    case when sum(r2014) over () = 0 then 0 else round(r2014 * 100/ sum(r2014) over (), 2) end as r2014,
    case when sum(r2015) over () = 0 then 0 else round(r2015 * 100/ sum(r2015) over (), 2) end as r2015,
    case when sum(r2016) over () = 0 then 0 else round(r2016 * 100/ sum(r2016) over (), 2) end as r2016,
    case when sum(r2017) over () = 0 then 0 else round(r2017 * 100/ sum(r2017) over (), 2) end as r2017
from (
    select pc.category_name, 
        nvl(count(case when extract(year from o.order_date) = 2013 then 1 end), 0) as r2013,
        nvl(count(case when extract(year from o.order_date) = 2014 then 2 end), 0) as r2014,
        nvl(count(case when extract(year from o.order_date) = 2015 then 3 end), 0) as r2015,
        nvl(count(case when extract(year from o.order_date) = 2016 then 4 end), 0) as r2016,
        nvl(count(case when extract(year from o.order_date) = 2017 then 5 end), 0) as r2017
    from order_items oi
    left join orders o on oi.order_id = o.order_id
    left join products p on p.product_id = oi.product_id
    left join product_categories pc on p.category_id = pc.category_id
    group by category_name
);


/* 24) Determine a coefficient that determines the average number of units of
    a product ordered in a single order in a given year and category. 
    We define this indicator as:
*/

select category_name,
    case when r2013 = 0 then 0 else round(s2013 / r2013, 0) end as r2013,
    case when r2014 = 0 then 0 else round(s2014 / r2014, 0) end as r2014,
    case when r2015 = 0 then 0 else round(s2015 / r2015, 0) end as r2015,
    case when r2016 = 0 then 0 else round(s2016 / r2016, 0) end as r2016,
    case when r2017 = 0 then 0 else round(s2017 / r2017, 0) end as r2017
from (
    select pc.category_name, 
        nvl(count(case when extract(year from o.order_date) = 2013 then 1 end), 0) as r2013,
        nvl(count(case when extract(year from o.order_date) = 2014 then 2 end), 0) as r2014,
        nvl(count(case when extract(year from o.order_date) = 2015 then 3 end), 0) as r2015,
        nvl(count(case when extract(year from o.order_date) = 2016 then 4 end), 0) as r2016,
        nvl(count(case when extract(year from o.order_date) = 2017 then 5 end), 0) as r2017,
        nvl(sum(case when extract(year from o.order_date) = 2013 then quantity end), 0) as s2013,
        nvl(sum(case when extract(year from o.order_date) = 2014 then quantity end), 0) as s2014,
        nvl(sum(case when extract(year from o.order_date) = 2015 then quantity end), 0) as s2015,
        nvl(sum(case when extract(year from o.order_date) = 2016 then quantity end), 0) as s2016,
        nvl(sum(case when extract(year from o.order_date) = 2017 then quantity end), 0) as s2017
    from order_items oi
    left join orders o on oi.order_id = o.order_id
    left join products p on p.product_id = oi.product_id
    left join product_categories pc on p.category_id = pc.category_id
    group by category_name
);


/* 25) Calculate how the profits from the sale of a given product have changed in
    a given year. Only orders that have not been cancelled should be taken into account.
    Display the name of a given product along with the total amount from orders.
    Some products may have different versions (different id and descriptions),
    but we only take into account their names.
*/

select PRODUCT_NAME, nvl(R2013, 0) as r2013, nvl(R2014, 0) as r2014,
    nvl(R2015, 0) as r2015, nvl(R2016, 0) as r2016, nvl(R2017, 0) as r2017
from (
    select p.product_name, oi.unit_price * oi.quantity as total_price, 
        extract(year from o.order_date) as yr
    from orders o 
    inner join order_items oi on o.order_id = oi.order_id
    inner join products p on oi.product_id = p.product_id
    where o.status <> 'Canceled'
) pivot (
    sum(total_price) 
    for yr in (
        2013 as r2013,
        2014 as r2014,
        2015 as r2015,
        2016 as r2016,
        2017 as r2017
    )
);