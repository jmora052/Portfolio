# Case Study: Danny's Diner - Analysis
Remember, all of these questions must be answered in a single SQL query. Also keep in mind, this is only a sampling of Danny's full data, and he wants to be able to apply these queries to his full dataset.
Find the [full project scope here](https://github.com/jmora052/Portfolio/blob/a18b595b56d79c3f2a0d6d208fd74f12f258c007/Case%20Study:%20Danny's%20Diner/README.md).

## 1. What is the total amount each customer spent at the restaurant?

### SQL and Reasoning

To find this answer, we need to simply use a SUM aggregate function with a GROUP BY clause to find how much each customer spent.

```SQL
SELECT s.customer_id, SUM(m.price) AS total_spent
FROM sales as s
JOIN me as m
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
Further exploration reveals that customer A typically orders 2 items, suggesting they typically visit with another person.


## 2. How many days has each customer visited the restaurant?

### SQL and Reasoning

Here, we need to find the number of visits to the restaurant. We can't simply do a count of sales, otherwise days where a customer ordered 2 items will be counted as two separate visits.
Instead, we use a DISTINCT function to remove duplicate dates and put it in a CTE to COUNT the deduped date column.

```SQL
WITH distinct_days AS
(
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

While the first inclination is to use MIN(order_date) to get the first order date, if there was more than 1 item in the first order, it would not be reflected.
Instead, we can use either RANK() or DENSE_RANK(). DENSE_RANK would be best practice here due to the nature of what we're ranking.
We partition by customer_id, since we're looking for a ranking per customer.

Then, we use a CTE to show only the two fields requested and to ensure only the items with a rank of 1 are shown, the first item ordered by each customer.

```SQL
WITH CTE_purchase_order AS
(
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
WITH CTE_top_seller AS
(
	SELECT m.product_name, count(s.product_id) as total_bought
	FROM sales as s
	JOIN menu as m
		ON s.product_id = m.product_id
	GROUP BY s.product_id
	ORDER BY total_bought DESC
),

CTE_denserank AS
(
	SELECT product_name, total_bought,
	DENSE_RANK() OVER (ORDER BY total_bought DESC) as purchase_frequency
	FROM CTE_top_seller
)

SELECT product_name, total_bought
FROM CTE_denserank
WHERE purchase_frequency = 1
```

### Answer

| product_name | total_bought |
|--------------|--------------|
| ramen        | 8            |

All of this code for such a deceptively simple answer. But the important thing is that this answer is scalable to all of the data Danny might have.

## 5. Which item was the most popular for each customer?

### SQL and Reasoning

Similar to the previous question, we can create a count of how many times a customer purchased each item with a GROUP BY clause. Again, we do this in case a customer has multiple favorite items.
Then, we simply DENSE_RANK the count and show rank = 1 to show each customer's favorite item.

```SQL
WITH CTE_item_count AS
(
	SELECT s.customer_id, m.product_name, count(s.product_id) as times_purchased,
	DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY count(s.product_id) DESC) as favorite_item
	FROM sales as s
	JOIN menu as m
		ON s.product_id = m.product_id
	GROUP BY s.customer_id, s.product_id
)
SELECT customer_id, product_name
FROM CTE_item_count
WHERE favorite_item = 1
```

### Answer

| customer_id | product_name |
|-------------|--------------|
| A           | ramen        |
| B           | ramen        |
| B           | curry        |
| B           | sushi        |
| C           | ramen        |

We can see that customer B has ordered a little bit of everything. We can see that he enjoys the restaurant as a whole, so he might be a good customer to target as an influencer or encourage to leave a review.
We can also see that the ramen appears as a crowd-favorite, so that might be a good marketing opportunity. Further data mining would help strategy here.

## 6. Which item was purchased first by the customer after they became a member?

### SQL and Reasoning

Here, we need to work with the members table and use the join_date as a baseline. We need to find the first item's order_date that appears after the join_date. Then, since the question asks for the item specifically, we also need to JOIN the menu table, since that one contains product_name.

We will also need to make an assumption, since we don't have DATETIME data. Customer A signed up for a membership and ordered an item on the same day. Since the question asks specifically for the purchase AFTER they became a member, our best practice here would be to exclude the purchase made on the same day. That way, if they ever change the order_date column to DATETIME, the query will still provide the correct answer.

I recommend proceding with best practice and letting the client know.

```SQL
WITH CTE_after_membership_item AS
(
	SELECT s.customer_id, product_name, order_date,
	DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date ASC) as first_item
	FROM sales as s
	JOIN members as mem
		ON s.customer_id = mem.customer_id
	JOIN menu as m
		ON s.product_id = m.product_id
	WHERE order_date > join_date
)
SELECT customer_id, product_name as first_item
FROM CTE_after_membership_item
WHERE first_item = 1
```

### Answer

| customer_id | first_item |
|-------------|------------|
| A           | ramen      |
| B           | sushi      |

## 7. Which item was purchased just before the customer became a member?

### SQL and Reasoning

This question will be the exact opposite of the last question. Here we're trying to find a "trigger" item to a customer starting their membership. Since again, we don't have DATETIME data, and it's unlikely that a customer's trigger item is happening at the same time as their purchase, we're again excluding a purchase on join_date from the results. We'll be following this assumption for the rest of this case study.

```SQL
WITH CTE_before_membership_item AS
(
	SELECT s.customer_id, product_name, order_date,
	DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date DESC) as trigger_item
	FROM sales as s
	JOIN members as mem
		ON s.customer_id = mem.customer_id
	JOIN menu as m
		ON s.product_id = m.product_id
	WHERE order_date < join_date
)
SELECT customer_id, product_name as trigger_item
FROM CTE_before_membership_item
WHERE trigger_item = 1
```

### Answer

| customer_id | trigger_item |
|-------------|--------------|
| A           | sushi        |
| A           | curry        |
| B           | sushi        |

Without having DATETIME data, it's hard to make an analysis here for both customers' membership behaviors. What we do know is that customer B really liked the sushi!

## 8. What is the total items and amount spent for each member before they became a member?

### SQL and Reasoning

To answer this, we need to count a total spent by each customer and only include it if order_date < join_date.

```SQL
WITH CTE_before_membership_items AS
(
	SELECT s.customer_id, product_name, order_date, price
	FROM sales as s
	JOIN members as mem
		ON s.customer_id = mem.customer_id
	JOIN menu as m
		ON s.product_id = m.product_id
	WHERE order_date < join_date
)
SELECT customer_id, sum(price) as total_spent
FROM CTE_before_membership_items
GROUP BY customer_id
```

### Answer

| customer_id | total_spent |
|-------------|-------------|
| A           | 25          |
| B           | 40          |

## 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

### SQL and Reasoning

Let's break this down as there's a few things going on.
- Each $1 spent is 10 points, which we can do with price*10
- Each $1 spent on sushi is 20 points, which would be price*20 when product_name "sushi"
- We need to find the total number of points for each customer

To do this in one query, we need to use a CASE statement that assigns a *20 value to a column WHEN product_name is sushi, ELSE a *10 value if it's not.
Then, we need to SUM those values and GROUP BY customer.

```SQL
SELECT customer_id,
SUM(CASE
WHEN m.product_name = "sushi" THEN m.price*20
ELSE m.price*10 END) as lifetime_points_earned
FROM sales as s
JOIN menu as m
	ON s.product_id = m.product_id
GROUP BY customer_id
ORDER BY order_date
```

### Answer

| customer_id | lifetime_points_earned |
|-------------|------------------------|
| A           | 860                    |
| B           | 940                    |
| C           | 360                    |

## 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

### SQL and Reasoning

Let's break down this question:
- We want to create essentially 2 stages of point values based on date. During the membership promotion, and regular point value outside of that.
- Then we want to create a query that removes customer C and only counts points until the end of January.

Let's tackle the promotional piece first.

Defining the promotional period, we can see that it's the first week of joining the program, including the join date, meaning it would run for join_date + 6 days.
Then we can create our CASE statement. Our first statement needs to be the promotional piece, since that overrides any other values. Outside of that, if product_name = "sushi", point value is 20. Then if neither of those are true, then point value is 10.

So roughly:
CASE WHEN order_date BETWEEN join_date AND join_date + 6 THEN price*20
WHEN product_name = "sushi" THEN price*20
ELSE price*10.

To ensure that only the customers that became members are included in the data, we can simply use an inner JOIN.

Lastly, to ensure only January is counted, we could simply use a WHERE clause on the order_date, limiting to dates < February 1st, 2021. However, this wouldn't be the scalable solution as Danny could have data prior to January. So we use another BETWEEN clause.

```SQL
SELECT s.customer_id,
SUM(CASE 
	WHEN order_date BETWEEN join_date AND date("join_date","+6 days") THEN m.price*20
	WHEN m.product_name = "sushi" THEN m.price*20
	ELSE m.price*10 END) as january_points
FROM sales as s
JOIN menu as m
	ON s.product_id = m.product_id
JOIN members as mem
	ON s.customer_id = mem.customer_id
WHERE s.order_date BETWEEN "2021-01-01" AND "2021-01-31"
GROUP BY s.customer_id
ORDER BY order_date
```

### Answer

| customer_id | january_points |
|-------------|----------------|
| A           | 1370           |
| B           | 820            |

As we can see, customer A was likely highly motivated by earning points, earning 1.5x as many as customer B while spending the same amount. Customer A would be a good customer to target with points promotion to ensure they keep coming back!
