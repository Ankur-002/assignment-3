use mavenmovies;
 -- 1. **Rank the customers based on the total amount they've spent on rentals.**
 select distinct c.customer_id as id ,concat(first_name, " ", last_name) as name, sum(amount) over(),
 sum(amount) over (order by c.customer_id) as total
 from customer c inner join payment p on c.customer_id = p.customer_id;

-- 2. **Calculate the cumulative revenue generated by each film over time.**
Select distinct f.film_id, title, sum(amount) over (order by film_id) from
film f inner join inventory i  on f.film_id = i.film_id
inner join rental r on r.inventory_id = i.inventory_id
inner join payment p on p.rental_id = r.rental_id;

-- 3. **Determine the average rental duration for each film, considering films with similar lengths.**
select distinct f.film_id, title, avg(rental_duration) over (order by film_id) from 
film f inner join inventory i on f.film_id = i.film_id 
inner join rental r on r.inventory_id = i.inventory_id; 

-- 4. **Identify the top 3 films in each category based on their rental counts.**

WITH RankedFilms AS (
    SELECT
        c.name AS category,
        f.title AS film_title,
        COUNT(r.rental_id) AS rental_count,
        ROW_NUMBER() OVER (PARTITION BY c.category_id ORDER BY COUNT(r.rental_id) DESC) AS rank_within_category
    FROM category c
    inner JOIN film_category fc ON c.category_id = fc.category_id
    inner JOIN film f ON fc.film_id = f.film_id
    LEFT JOIN inventory i ON f.film_id = i.film_id
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
    GROUP BY c.category_id, f.film_id, f.title
)
SELECT category, film_title, rental_count
FROM RankedFilms
WHERE rank_within_category <= 3;

-- 5. calculate the difference in total rental counts between each customer total rentals and the avg rental across all the customer.

SELECT
    customer_id,
    total_rentals,
    AVG(total_rentals) OVER () AS avg_rentals_across_all_customers,
    total_rentals - AVG(total_rentals) OVER () AS rental_count_difference
FROM (
    SELECT
        c.customer_id, COUNT(r.rental_id) AS total_rentals
    FROM customer c
    inner JOIN rental r ON c.customer_id = r.customer_id
    GROUP BY c.customer_id
) AS customer_rentals;

-- 6. find the monthly revenue trend for entire rental store over time.

WITH MonthlyRevenue AS (
    SELECT
        DATE_FORMAT(payment.payment_date, '%Y-%m') AS month,
        SUM(payment.amount) AS monthly_revenue,
        ROW_NUMBER() OVER (ORDER BY DATE_FORMAT(payment.payment_date, '%Y-%m')) AS month_rank
    FROM payment
    GROUP BY DATE_FORMAT(payment.payment_date, '%Y-%m')
)
SELECT month, monthly_revenue,
LAG(monthly_revenue) OVER (ORDER BY month_rank) AS previous_month_revenue
FROM MonthlyRevenue;

-- 7. identify the customers whose total spending on rental falls within the top 20% of all customers.
with top_customer as (
select c.customer_id, concat(c.first_name, " ", c.last_name) as name, sum(p.amount) as spending,
percent_rank() over (order by sum(amount) desc) as spending_percentage from 
customer c inner join payment p on c.customer_id = p.customer_id
group by c.customer_id)
select customer_id,name, spending
from top_customer
where spending_percentage <= 0.2;

-- 8. calculate the running total of rental per category, ordered by rental count.
with category_total as (
select category_id, count(*) as rental_count, 
row_number () over (order by count(*) desc) as category_rank
from film_category 
group by category_id)
select ct.category_id, c.name as category_name, ct.rental_count,
sum(ct.rental_count) over (order by ct.category_rank) as running_cost
from category_total ct inner join category c on ct.category_id = c.category_id
order by ct.category_rank;

-- 9. find the films that have been rented less than the average rental count for their respective category.
with film_rental as (
select f.film_id, fc.category_id, count(r.rental_id) as rental_count,
avg(count(r.rental_id)) over (partition by fc.category_id) as avg_count,
row_number() over (partition by fc.category_id order by count(r.rental_id) desc) as film_rank
from film f
inner join film_category fc on f.film_id = fc.film_id
inner join inventory i on i.film_id = f.film_id
inner join rental r on r.inventory_id = i.inventory_id
group by f.film_id, fc.category_id)

select fr.film_id, fr.category_id, f.title, fr.rental_count, fr.avg_count
from film_rental fr inner join film f on f.film_id = fr.film_id
where fr.rental_count < fr.avg_count
order by fr.category_id, fr.film_rank; 

-- 10. Identify the top 5 film with the highest revenue and display the revenue generated in each month.

with monthly_revenue as (
select f.film_id, f.title, 
date_format(r.rental_date, '%y,%m') as rental_month, sum(p.amount) as revenue,
row_number() over (partition by date_format(r.rental_date, '%y,%m') order by sum(p.amount) desc) as film_rank
from film f 
inner join inventory i on f.film_id = i.film_id
inner join rental r on r.inventory_id = i.inventory_id
inner join payment p on p.rental_id = r.rental_id
group by f.film_id, f.title, rental_month)

select mr.film_id, mr.title, mr.rental_month, mr.revenue from monthly_revenue mr
where mr.film_rank <= 5
order by mr.rental_month, mr.film_rank;




