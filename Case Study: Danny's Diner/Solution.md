# Case Study: Danny's Diner - Analysis
Remember, all of these questions must be answered in a single SQL query.

## 1. What is the total amount each customer spent at the restaurant?

### SQL and Analysis

To find this answer, we need to simply use a SUM aggregate function with a GROUP BY clause to find how much each customer spent.

```SQL
SELECT s.customer_id, SUM(m.price) AS total_spent
FROM sales as s
JOIN me AS m
	ON s.product_id = m.product_id
GROUP BY customer_id
ORDER BY customer_id
```

### Answer
| customer_id | total_spent |
|-------------|-------------|
| A           | 76          |
| B           | 74          |
| C           | 36          |

It appears that customer C only spent half as much as A and B.
Further exploration reveals that customer A typically orders 2 items, suggesting they come with another person.


## 2. How many days has each customer visited the restaurant?

### SQL and Reasoning

Here, we need to find the number of visits to the restaurant. We can't simply do a count of sales, otherwise days where a customer ordered 2 items will be counted as two separate visits.
Instead, we use a DISTINCT function to remove duplicate dates and put it in a CTE to COUNT the deduped date column.

```SQL
WITH distinct_days
AS (
SELECT DISTINCT customer_id, order_date
FROM sales
)
SELECT customer_id, COUNT(order_date) as days_visited
FROM distinct_days
GROUP BY customer_id
```

### Answer

| customer_id | days_visited |
|-------------|--------------|
| A           | 4            |
| B           | 6            |
| C           | 2            |

We can see that although customers A and B have spent similar amounts, A spends more per visit, and B visits more often!


## 3. What was the first item from the menu purchased by each customer?

### SQL and Reasoning

While the first inclination is to use MIN(order_date) to get the first order date, if there was more than 1 item in the first order, it will not be reflected.
Instead, we can use either RANK() or DENSE_RANK(). DENSE_RANK would be best practice here due to the nature of what we're ranking.
We partition by customer_id, since we're looking for a ranking per customer.

Then, we use a CTE to show only the two fields requested and to ensure only the items with a rank of 1 are shown, the first item ordered by each customer.

```SQL
WITH CTE_purchase_order
AS (
SELECT s.customer_id, s.order_date, s.product_id, m.product_name,
DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) as purchase_order
FROM sales as s
JOIN menu as m
	ON s.product_id = m.product_id
)
SELECT customer_id, product_name as first_purchase
FROM CTE_purchase_order
WHERE purchase_order = 1
```

### Answer

| customer_id | first_purchase |
|-------------|----------------|
| A           | sushi          |
| A           | curry          |
| B           | curry          |
| C           | ramen          |
| C           | ramen          |


## 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

### SQL and Reasoning

We need to find the item with the highest sale frequency and find how many times it was bought.
While the easiest solution would be to set a COUNT of product_id and ORDER BY DESC, then LIMIT 1, this would not be a scalable solution due to the possibility of multiple top sellers.
Since this is a sample of Danny's data, the more scalable solution would be to apply a DENSE_RANK function to a COUNT to ensure the top sellers are shown.

First, we'll need to create a CTE to grab a count of each item and order it by frequency. Then we just need to DENSE_RANK the results.
However, since the question asks for only two elements, the most purchased item and how many times it was purchased, we need to create a nested CTE to hide the DENSE_RANK column.

```SLQ
WITH CTE_top_seller
AS(
SELECT m.product_name, count(s.product_id) as total_bought
FROM sales as s
JOIN menu as m
ON s.product_id = m.product_id
GROUP BY s.product_id
ORDER BY total_bought DESC
),
CTE_denserank
AS(
SELECT product_name, total_bought,
DENSE_RANK() OVER (ORDER BY total_bought DESC) as purchase_frequency
FROM CTE_top_seller
)
SELECT product_name, total_bought
FROM CTE_denserank
WHERE purchase_frequency = 1
```

## Answer

| product_name | total_bought |
|--------------|--------------|
| ramen        | 8            |

All of this code for such a deceptively simple answer. But the important thing is that this answer is scalable to all of the data Danny might have.

## Which item was the most popular for each customer?


Which item was purchased first by the customer after they became a member?
Which item was purchased just before the customer became a member?
What is the total items and amount spent for each member before they became a member?
If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
