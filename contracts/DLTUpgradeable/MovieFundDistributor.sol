// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IDLTUpgradeable} from "./interfaces/IDLTUpgradeable.sol";
import {IDLTReceiverUpgradeable} from "./interfaces/IDLTReceiverUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "./MappingToArrays.sol";
import "./MetaDataDescriptor.sol";

contract MovieFundDistributor is
    Initializable,
    Context,
    IDLTUpgradeable,
    ERC721,
    ERC721URIStorage
{
    //structs
    struct Movie {
        address producer;
        uint256 movieId;
        string movieName;
        uint256 totalDepartments;
    }

    struct Departments {
        address departmentManager;
        uint256 movieId;
        uint256 departmentId;
        string departmentName;
        uint256 noOfEmployees; //right now not using this feature
        bool salaryPaid;
    }

    struct Employee{
    address employeeAddress;
    uint256 mainId;
    uint256 departmentId;
    uint256 employeeId;
    uint256 salary;
}

    using Strings for address;
    using Strings for uint256;
    MappingToArrays mappingToArrays;
    MetaDataDescriptor metaDataDescriptor;

    string private _name;
    string private _symbol;
    uint256 currentIndex = 1;
    uint256 MOVIE_COUNTER = 1;
    mapping(uint256 => uint256) DEPARTMENT_COUNTER;
     mapping(uint256 => mapping(uint256=>uint256)) EMPLOYEE_COUNTER;
    mapping(uint256 => Movie) public movies;
    mapping(uint256 => mapping(uint256 => Departments)) public departments;
    mapping(uint256 => string) _tokenURIs;

    // Balances
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _balances;

    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => uint256))))
        private _allowances;
    mapping(uint256 => mapping(address => bool)) public movieExists;
    mapping(uint256 => mapping(uint256 => mapping(address => bool)))
        public departmentExists;
    mapping(uint256=>mapping(uint256=>mapping(uint256=>Employee)))employees;
    mapping(uint256=>mapping(uint256=>mapping(uint256=>bool)))employeeExists;

    event MovieAdded(uint256 MOVIE_INDEX, string movieName);
    event DepartmentAdded(uint256 movieId, uint256 departmentId);
    event DepartmentRemoved(uint256 movieId, uint256 departmentId);
    event MovieRemoved(uint256 movieId);
    event MaintainceDistributed(uint256 movieId, uint256 budget);
    event DepartmentFundTransferred(
        address from,
        address to,
        uint256 fromDepartmentId,
        uint256 toDepartmentId
    );

    modifier onlyProducer(uint256 movieId) {
        require(msg.sender == movies[movieId].producer, "Only Producer");
        _;
    }

    modifier onlyManager(uint256 movieId, uint256 departmentId) {
        require(
            msg.sender == departments[movieId][departmentId].departmentManager,
            "Department:only manager"
        );
        _;
    }

    constructor(address _mappingToArrays,address _metaDataDescriptor) ERC721("Dual Layer Token", "DLT") {
        mappingToArrays = MappingToArrays(_mappingToArrays);
        metaDataDescriptor=MetaDataDescriptor(_metaDataDescriptor);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __DLT_init(string memory name, string memory symbol)
        internal
        onlyInitializing
    {
        __DLT_init_unchained(name, symbol);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __DLT_init_unchained(string memory name, string memory symbol)
        internal
        onlyInitializing
    {
        _name = name;
        _symbol = symbol;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    function onERC721Received() external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // solhint-disable-next-line ordering
    function approve(
        address spender,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        require(spender != owner, "DLT: approval to current owner");
        _approve(owner, spender, mainId, subId, budget);
        return true;
    }

    /**
     * @dev See {DLT-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override(ERC721, IERC721, IDLTUpgradeable)
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IDLT-transferFrom}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `budget`.
     * - the caller must have allowance for `sender`'s tokens of at least `budget`.
     */
    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) public virtual returns (bool) {
        _safeTransferFrom(sender, recipient, mainId, subId, budget, "");
        return true;
    }

    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) public virtual returns (bool) {
        _safeTransferFrom(sender, recipient, mainId, subId, budget, data);
        return true;
    }

    function safeBatchTransferFrom(
        address sender,
        address recipient,
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata budgets,
        bytes calldata data
    ) public returns (bool) {
        address spender = _msgSender();

        require(
            _isApprovedOrOwner(sender, spender),
            "DLT: caller is not token owner or approved for all"
        );

        _safeBatchTransferFrom(
            sender,
            recipient,
            mainIds,
            subIds,
            budgets,
            data
        );
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) public virtual returns (bool) {
        _transferFrom(sender, recipient, mainId, subId, budget);
        return true;
    }

    function subBalanceOf(
        address account,
        uint256 mainId,
        uint256 subId
    ) public view virtual override returns (uint256) {
        return _balances[mainId][account][subId];
    }

    /**
     * @dev See {IDLT-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `mainIds` and `subIds` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata mainIds,
        uint256[] calldata subIds
    ) public view returns (uint256[] memory) {
        require(
            accounts.length == mainIds.length &&
                accounts.length == subIds.length,
            "DLT: accounts, mainIds and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = subBalanceOf(accounts[i], mainIds[i], subIds[i]);
        }

        return batchBalances;
    }

    function allowance(
        address owner,
        address spender,
        uint256 mainId,
        uint256 subId
    ) public view virtual override returns (uint256) {
        return _allowance(owner, spender, mainId, subId);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721, IERC721, IDLTUpgradeable)
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Safely mints `budget` in specific `subId` in specific `mainId` and transfers it to `recipient`.
     *
     * Requirements:
     *
     * - If `recipient` refers to a smart contract, it must implement {IDLTReceiverUpgradeable-onDLTReceived},
     *   which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        _safeMint(recipient, mainId, subId, budget, "");
    }

    /**
     * @dev Same as [`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IDLTReceiverUpgradeable-onDLTReceived} to contract recipients.
     */
    function _safeMint(
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) internal virtual {
        _mint(recipient, mainId, subId, budget);
        require(
            _checkOnDLTReceived(
                address(0),
                recipient,
                mainId,
                subId,
                budget,
                data
            ),
            "DLT: transfer to non DLTReceiver implementer"
        );
    }

    /**
     * @dev Safely transfers `budget` from `subId` in specific `mainId from `sender` to `recipient`,
     * checking first that contract recipients
     * are aware of the DLT standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `recipient`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `budget` sender can transfer at least his balance.
     * - If `recipient` refers to a smart contract, it must implement {IDLTReceiverUpgradeable-onDLTReceived},
     *    which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) internal virtual {
        _transfer(sender, recipient, mainId, subId, budget);
        require(
            _checkOnDLTReceived(sender, recipient, mainId, subId, budget, data),
            "DLT: transfer to non DLTReceiver implementer"
        );
    }

    function _safeTransferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) internal virtual {
        address spender = _msgSender();

        if (!_isApprovedOrOwner(sender, spender)) {
            _spendAllowance(sender, spender, mainId, subId, budget);
        }

        _safeTransfer(sender, recipient, mainId, subId, budget, data);
    }

    /**
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `recipient` refers to a smart contract, it must implement {IDLTReceiverUpgradeable-onDLTReceived} and return
     *  the acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address sender,
        address recipient,
        uint256[] memory mainIds,
        uint256[] memory subIds,
        uint256[] memory budgets,
        bytes memory data
    ) internal virtual {
        require(
            mainIds.length == subIds.length && mainIds.length == budgets.length,
            "DLT: mainIds, subIds and budgets length mismatch"
        );
        require(recipient != address(0), "DLT: transfer to the zero address");

        address operator = _msgSender();

        for (uint256 i = 0; i < mainIds.length; ++i) {
            uint256 mainId = mainIds[i];
            uint256 subId = subIds[i];
            uint256 budget = budgets[i];
            uint256 senderBalance = _balances[mainId][sender][subId];

            require(
                senderBalance >= budget,
                "DLT: insufficient balance for transfer"
            );
            unchecked {
                _balances[mainId][sender][subId] = senderBalance - budget;
            }
            _balances[mainId][recipient][subId] += budget;
        }

        emit TransferBatch(
            operator,
            sender,
            recipient,
            mainIds,
            subIds,
            budgets
        );
        require(
            _checkOnDLTBatchReceived(
                sender,
                recipient,
                mainIds,
                subIds,
                budgets,
                data
            ),
            "DLT: transfer to non DLTReceiver implementer"
        );
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        address spender = _msgSender();

        if (!_isApprovedOrOwner(sender, spender)) {
            _spendAllowance(sender, spender, mainId, subId, budget);
        }

        _transfer(sender, recipient, mainId, subId, budget);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        uint256 currentAllowance = _allowance(owner, spender, mainId, subId);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= budget, "DLT: insufficient allowance");
            unchecked {
                _approve(
                    owner,
                    spender,
                    mainId,
                    subId,
                    currentAllowance - budget
                );
            }
        }
    }

    /**
     * @dev Sets `budget` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        require(owner != address(0), "DLT: approve from the zero address");
        require(spender != address(0), "DLT: approve to the zero address");

        _allowances[owner][spender][mainId][subId] = budget;
        emit Approval(owner, spender, mainId, subId, budget);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual override {
        require(owner != operator, "DLT: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Moves `budget` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `budget`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        require(sender != address(0), "DLT: transfer from the zero address");
        require(recipient != address(0), "DLT: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, mainId, subId, budget, "");

        require(
            _balances[mainId][sender][subId] >= budget,
            "DLT: insufficient balance for transfer"
        );
        unchecked {
            _balances[mainId][sender][subId] -= budget;
        }

        _balances[mainId][recipient][subId] += budget;

        emit Transfer(sender, recipient, mainId, subId, budget);

        _afterTokenTransfer(sender, recipient, mainId, subId, budget, "");
    }

    //All function are added from here Rest of the functions are from 6960 implementation
    function mintSubId(
        address account,
        uint256 mainId,
        uint256 subId,
        string memory name,
        uint256 budget,
        string memory _tokenURI
    ) internal virtual {
        require(account != address(0), "DLT: mint to the zero address");
        //   require(budget != 0, "DLT: mint zero budget");

        _mint(account, subId);

        _beforeTokenTransfer(address(0), account, mainId, subId, budget, "");

        _balances[mainId][account][subId] += budget;

        emit Transfer(address(0), account, mainId, subId, budget);

        _afterTokenTransfer(address(0), account, mainId, subId, budget, "");
        setTokenURI(subId, name, _tokenURI);
    }

    function mintMainId(
        address account,
        uint256 mainId,
        uint256 subId,
        string memory name,
        uint256 budget,
        string memory _tokenURI
    ) internal virtual {
        require(account != address(0), "DLT: mint to the zero address");
        //     require(budget != 0, "DLT: mint zero budget");

        _mint(account, mainId);

        _beforeTokenTransfer(address(0), account, mainId, subId, budget, "");

        _balances[mainId][account][subId] += budget;

        emit Transfer(address(0), account, mainId, subId, budget);

        _afterTokenTransfer(address(0), account, mainId, subId, budget, "");
        setTokenURI(mainId, name, _tokenURI);
    }

    function setTokenURI(
        uint256 _assetId,
        string memory name,
        string memory assetURI
    ) internal {
        string memory fullName = string(
            abi.encodePacked(name,metaDataDescriptor.uint2str(_assetId))
        );
        string memory _assetURI = metaDataDescriptor.generateJSON(fullName, assetURI);
        _tokenURIs[_assetId] = _assetURI;
        _setTokenURI(_assetId, _assetURI);
    }

     function tokenURI(uint256 _assetId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_assetId);
    }

    function addMovie(
        address movieProducer,
        string memory movieName,
        string memory movieImage
    ) public {
        uint256 MOVIE_INDEX = MOVIE_COUNTER * 10;
        movies[MOVIE_INDEX] = Movie(movieProducer, MOVIE_INDEX, movieName, 0);
        mintMainId(movieProducer, MOVIE_INDEX, 0, movieName, 0, movieImage);
        movieExists[MOVIE_INDEX][movieProducer] = true;
        DEPARTMENT_COUNTER[MOVIE_INDEX] = 1;
        MOVIE_COUNTER++;
        emit MovieAdded(MOVIE_INDEX, movieName);
    }

    function addDepartment(
        address departmentManager,
        uint256 movieId,
        string memory departmentName,
        string memory departmentImage
    ) public onlyProducer(movieId) {
        uint256 DEPARTMENT_INDEX = movieId + DEPARTMENT_COUNTER[movieId];
        departments[movieId][DEPARTMENT_INDEX] = Departments(
            departmentManager,
            movieId,
            DEPARTMENT_INDEX,
            departmentName,
            0,true
        );
        mintSubId(
            departmentManager,
            movieId,
            DEPARTMENT_INDEX,
            departmentName,
            0,
            departmentImage
        );
        mappingToArrays.addToMapping(movieId, DEPARTMENT_INDEX);
        departmentExists[movieId][DEPARTMENT_INDEX][departmentManager] = true;
        DEPARTMENT_COUNTER[movieId]++;
        movies[movieId].totalDepartments++;
        EMPLOYEE_COUNTER[movieId][DEPARTMENT_INDEX]=1;
        emit DepartmentAdded(movieId, DEPARTMENT_INDEX);
    }


  //EMPLOYEE INDEX IS FROM 1 FOR EACH DEPARTMENT//how to track the paid employee salary.
    function addEmployee(uint256 movieId,uint256 departmentId,address employeeAddress,uint256 employeeSalary)public{
        require(msg.sender==departments[movieId][departmentId].departmentManager,"Department:not department manager");
        uint256 EMPLOYEE_INDEX=EMPLOYEE_COUNTER[movieId][departmentId];
        employees[movieId][departmentId][EMPLOYEE_INDEX]=Employee(employeeAddress,movieId,departmentId,EMPLOYEE_INDEX,employeeSalary);
         mappingToArrays.addToTwoKeyMapping(movieId,departmentId,EMPLOYEE_INDEX);
        EMPLOYEE_COUNTER[movieId][departmentId]++;
        departments[movieId][departmentId].noOfEmployees++;
        employeeExists[movieId][departmentId][EMPLOYEE_INDEX]=true;
    }

    function fundMovie(uint256 movieId, uint256 fund)
        public
        onlyProducer(movieId)
    {
        require(movieExists[movieId][msg.sender], "Movie: Doesn't exists");
        _balances[movieId][msg.sender][0] += fund;
    }

    function PayMaintainance(
        uint256 movieId,
        address depAddress,
        uint256 departmentId,
        uint256 maintainance
    ) public onlyProducer(movieId) {
        require(movieExists[movieId][msg.sender], "Movie: Doesn't exists");
         require(_balances[movieId][msg.sender][0]!=0,"Movie:Insufficient balance");
        require(
            departmentExists[movieId][departmentId][depAddress],
            "Department: doesn't exists"
        );
        _balances[movieId][depAddress][departmentId] += maintainance;
        _balances[movieId][msg.sender][0] -= maintainance;
        emit MaintainceDistributed(movieId, maintainance);
        departments[movieId][departmentId].salaryPaid=false;
    }

    function PayMaintainceToAllDepartments(
        uint256 movieId,
        uint256 totalMaintainance
    ) public onlyProducer(movieId) {
        require(movieExists[movieId][msg.sender], "Movie: Doesn't exists");
        uint256[] memory departmentIds = mappingToArrays.getArray(movieId);
        require(
            _balances[movieId][msg.sender][0] >= totalMaintainance,
            "Movie:Maintainance fee is not sufficient"
        );
        uint256 maintainance = totalMaintainance /
            movies[movieId].totalDepartments;
        for (uint256 i = 0; i < movies[movieId].totalDepartments; i++) {
            uint256 departmentId = departmentIds[i];
            address depAddress = departments[movieId][departmentId]
                .departmentManager;
            _balances[movieId][depAddress][departmentId] += maintainance;
            _balances[movieId][msg.sender][0] -= maintainance;
             departments[movieId][departmentId].salaryPaid=false;
        }
    }

    function transferDepartmentBalance(
        uint256 movieId,
        uint256 fromDepartmentId,
        uint256 toDepartmentId,
        address from,
        address to,
        uint256 transferValue
    ) public onlyProducer(movieId) {
        require(movieExists[movieId][msg.sender], "Movie: Doesn't exists");
        require(_balances[movieId][msg.sender][0]!=0,"Movie:Insufficient balance");
        require(
            departmentExists[movieId][fromDepartmentId][from],
            "Department: doesn't exists"
        );
        require(
            departmentExists[movieId][toDepartmentId][to],
            "Department: doesn't exists"
        );
        _balances[movieId][from][fromDepartmentId] -= transferValue;
        _balances[movieId][to][toDepartmentId] += transferValue;
        emit DepartmentFundTransferred(
            from,
            to,
            fromDepartmentId,
            toDepartmentId
        );
    }

        function transferEmployeeBalance(
        uint256 movieId,
        uint256 departmentId,
        uint256 fromEmployeeId,
        uint256 toEmployeeId,
        address from,
        address to,
        uint256 transferValue
    ) public onlyProducer(movieId) {
        require(movieExists[movieId][msg.sender], "Movie: Doesn't exists");
        //to check if the employees from same movie and same department add logic
        require(employeeExists[movieId][departmentId][fromEmployeeId],"Employee:doesn't exists");
        require(employeeExists[movieId][departmentId][toEmployeeId],"Employee:doesn't exists");
        _balances[movieId][from][fromEmployeeId] -= transferValue;
        _balances[movieId][to][toEmployeeId] += transferValue;
        emit DepartmentFundTransferred(
            from,
            to,
            fromEmployeeId,
            toEmployeeId
        );
    }

     function addEmployeesalary(uint256 movieId,uint256 departmentId)public{
          require(msg.sender==departments[movieId][departmentId].departmentManager,"Department:not allowed");
            require(
            departmentExists[movieId][departmentId][msg.sender],
            "Department: doesn't exists"
        );
          require(!departments[movieId][departmentId].salaryPaid,"Department: salary is paid");
        
        uint256 totalEmployees=departments[movieId][departmentId].noOfEmployees;
         uint256[] memory employeeIds = mappingToArrays.getTwoKeyArray(movieId,departmentId);
        for (uint256 i = 0; i < totalEmployees; i++) {
            uint256 employeeId=employeeIds[i];
            address employeeAddress = employees[movieId][departmentId]
                [employeeId].employeeAddress;
                uint256 employeeSalary = employees[movieId][departmentId]
                [employeeId].salary;
                 require(_balances[movieId][msg.sender][departmentId]>=employeeSalary,"Department:Insufficient Balance");
            safeTransferFrom(msg.sender,employeeAddress,movieId,departmentId,employeeSalary);
        }
        departments[movieId][departmentId].salaryPaid=true;
    }

    function removeMovie(uint256 movieId, address _producer)
        public
        onlyProducer(movieId)
    {
        require(movieExists[movieId][_producer], "Movie: Doesn't exists");
        require(
            _balances[movieId][_producer][0] == 0,
            "Movie:Balance is not zero"
        );
        delete movies[movieId];
        delete movieExists[movieId][_producer];
        uint256 budget = _balances[movieId][_producer][0];
        _burn(_producer, movieId, 0, budget);
        emit MovieRemoved(movieId);
    }

    function removeDepartment(
        uint256 movieId,
        uint256 departmentId,
        address _departmentManager
    ) public onlyProducer(movieId) {
        require(
            departmentExists[movieId][departmentId][_departmentManager],
            "Department: doesn't exists"
        );
        require(
            _balances[movieId][_departmentManager][departmentId] == 0,
            "Department:Balance is not zero"
        );
        uint256 budget = _balances[movieId][_departmentManager][departmentId];
        _burn(_departmentManager, movieId, departmentId, budget);
        delete departmentExists[movieId][departmentId][_departmentManager];
        delete departments[movieId][departmentId];
        mappingToArrays.removeFromMapping(movieId,departmentId);
        movies[movieId].totalDepartments--;
        emit DepartmentRemoved(movieId, departmentId);
    }

       function removeEmployee(uint256 movieId,uint256 departmentId,uint256 employeeId,address employeeAddress)public{
        require(msg.sender==departments[movieId][departmentId].departmentManager,"Department:not allowed");
        require(_balances[movieId][employeeAddress][departmentId]==0,"Employee:balance is not zero");
        //since all employee ids are continous logic to update all employee id
        //we have to update _balance array
        delete employees[movieId][departmentId][employeeId];
        departments[movieId][departmentId].noOfEmployees--;
        mappingToArrays.removeFromTwoKeyMapping(movieId,departmentId,employeeId);
         employeeExists[movieId][departmentId][employeeId]=false;
    }


    //Allfunction included above section rest of the code remains same as given in 6960

    function _mint(
        address account,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        require(account != address(0), "DLT: mint to the zero address");
        require(budget != 0, "DLT: mint zero budget");

        _mint(account,mainId);

        _beforeTokenTransfer(address(0), account, mainId, subId, budget, "");

        _balances[mainId][account][subId] += budget;

        emit Transfer(address(0), account, mainId, subId, budget);

        _afterTokenTransfer(address(0), account, mainId, subId, budget, "");
    }

    /**
     * @dev Destroys `budget` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `recipient` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `budget` tokens.
     */
    function _burn(
        address account,
        uint256 mainId,
        uint256 subId,
        uint256 budget
    ) internal virtual {
        require(account != address(0), "DLT: burn from the zero address");
       // require(budget != 0, "DLT: burn zero budget");

        uint256 fromBalanceSub = _balances[mainId][account][subId];
        require(fromBalanceSub >= budget, "DLT: insufficient balance");

        _beforeTokenTransfer(account, address(0), mainId, subId, budget, "");

        unchecked {
            _balances[mainId][account][subId] -= budget;

            // Overflow not possible: budget <= fromBalanceMain <= totalSupply.
        }

        emit Transfer(account, address(0), mainId, subId, budget);

        _afterTokenTransfer(account, address(0), mainId, subId, budget, "");

        //  _burn(subId);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `sender` and `recipient` are both non-zero, `budget` of ``sender``'s tokens
     * will be transferred to `recipient`.
     * - when `sender` is zero, `budget` tokens will be minted for `recipient`.
     * - when `recipient` is zero, `budget` of ``sender``'s tokens will be burned.
     * - `sender` and `recipient` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `sender` and `recipient` are both non-zero, `budget` of ``sender``'s tokens
     * has been transferred to `recipient`.
     * - when `sender` is zero, `budget` tokens have been minted for `recipient`.
     * - when `recipient` is zero, `budget` of ``sender``'s tokens have been burned.
     * - `sender` and `recipient` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) internal virtual {}

    function _allowance(
        address owner,
        address spender,
        uint256 mainId,
        uint256 subId
    ) internal view virtual returns (uint256) {
        return _allowances[owner][spender][mainId][subId];
    }

    function _isApprovedOrOwner(address sender, address spender)
        internal
        view
        virtual
        returns (bool)
    {
        return (sender == spender || isApprovedForAll(sender, spender));
    }

    /**
     * @dev Internal function to invoke {IDLTReceiverUpgradeable-onDLTReceived} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param sender address representing the previous owner of the given token ID
     * @param recipient target address that will receive the tokens
     * @param mainId target address that will receive the tokens
     * @param subId target address that will receive the tokens
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnDLTReceived(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 budget,
        bytes memory data
    ) private returns (bool) {
        if (recipient.code.length > 0) {
            try
                IDLTReceiverUpgradeable(recipient).onDLTReceived(
                    _msgSender(),
                    sender,
                    mainId,
                    subId,
                    budget,
                    data
                )
            returns (bytes4 retval) {
                return retval == IDLTReceiverUpgradeable.onDLTReceived.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("DLT: transfer to non DLTReceiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _checkOnDLTBatchReceived(
        address sender,
        address recipient,
        uint256[] memory mainIds,
        uint256[] memory subIds,
        uint256[] memory budgets,
        bytes memory data
    ) private returns (bool) {
        if (recipient.code.length > 0) {
            try
                IDLTReceiverUpgradeable(recipient).onDLTBatchReceived(
                    _msgSender(),
                    sender,
                    mainIds,
                    subIds,
                    budgets,
                    data
                )
            returns (bytes4 retval) {
                return
                    retval ==
                    IDLTReceiverUpgradeable.onDLTBatchReceived.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("DLT: transfer to non DLTReceiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
