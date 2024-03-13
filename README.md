# Movie Fund Distributor-ERC6960

The Movie Fund Distributor is a Solidity smart contract designed to manage funds and operations within a movie production house using ERC6960-Dual Layer Token.It provides functionalities for adding movies, departments, and employees, as well as distributing funds and paying employee salaries. The ERC6960 Dual Layer Token combines the functionalities of ERC-20, ERC-721, and ERC-1155, adding a classification layer that uses mainId as the main asset type identifier and subId as the unique attributes or variations of the main asset.

## Key Features

- **Adding Movies**: Producers can add new movies to the production house, specifying the movie name and associated image.
- **Adding Departments**: Producers can add departments to each movie, defining the department name and image.
- **Adding Employees**: Department managers can add employees to their departments, specifying the employee's address and salary.
- **Distributing Funds**: Producers can distribute funds to movies and departments within the production house.
- **Paying Salaries**: Department managers can pay salaries to employees in their departments using allocated funds.

## Usage

1. **Deploy the Contract**: Deploy the MovieFundDistributor contract on the Ethereum blockchain.
2. **Add Movies**: Producers can add movies to the production house using the addMovie function, providing the movie name and image.
3. **Add Departments**: For each movie, producers can add departments using the addDepartment function, specifying the department name and image.
4. **Add Employees**: Department managers can add employees to their departments using the addEmployee function, providing the employee's address and salary.
5. **Distribute Funds**: Producers can distribute funds to movies and departments using the appropriate functions.
6. **Pay Salaries**: Department managers can pay employee salaries using allocated funds by calling the addEmployeesalary function.
