# Backlog: create these as GitHub issues and Azure Boards items

## Application stories
1. As a shopper I can see the list of products.
2. As a shopper I can add products to a cart.
3. As a shopper I can check out and receive an order number.
4. As a shopper I cannot buy more than the stock available.
5. As an admin I can add a new product through the API.
6. As the team I can see the deployed version on the page.
7. (Stretch) As a user I can log in.
8. (Stretch) As an admin I can list orders.

## Pipeline tasks
- Gradle wrapper committed; 15 tests pass locally
- Jenkins installed, credentials added, manual run green
- Webhook triggers a build
- Ansible deploy to staging works
- Production approval gate works
- Rollback proven with a failing build
- Azure Pipelines build/test green
- Report, diagram and screenshots
- Demo rehearsed and recorded

Use one branch per issue and a PR that says `Closes #N`.
