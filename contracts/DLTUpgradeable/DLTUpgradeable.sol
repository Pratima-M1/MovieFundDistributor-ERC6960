// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { IDLTUpgradeable } from "./interfaces/IDLTUpgradeable.sol";
import { IDLTReceiverUpgradeable } from "./interfaces/IDLTReceiverUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";

contract DLTUpgradeable is Initializable, Context, IDLTUpgradeable,ERC721,ERC721URIStorage {
    struct Movie{
        address producer;
    uint256 movieId;
    string movieName;
    uint256 totalDepartments;
}

struct Departments{
    uint256 departmentId;
    uint256 movieId;
    string departmentName;
    uint256 noOfEmployees;
}

struct Employees{
     address employee;
    uint256 movieId;
    uint256 departmentId;
    uint256 salary;
}

      using Strings for address;
    using Strings for uint256;

    string private _name;
    string private _symbol;

uint256 movieIdCounter=1;
uint256 departmentIdCounter=1;
uint256 employeeIdCounter=1;
mapping(uint256=>Movie) movies;
mapping(uint256=>mapping(uint256=>Departments))departments;
mapping(uint256=>uint256)departmentCount;
mapping(uint256=>mapping(uint256=>mapping(uint256=>Employees))) employeeDetails;
mapping(uint256=>mapping(uint256=>uint256))employeeCount;
mapping(uint256=>string)_tokenURIs;

    // Balances
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        internal _balances;

    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => uint256))))
        private _allowances;

 event SalaryDistributed(uint256 movieId,uint256 departmentId,uint256 amount);
 constructor() ERC721("Dual Layer Token", "DLT") {}

    // solhint-disable-next-line func-name-mixedcase
    function __DLT_init(
        string memory name,
        string memory symbol
    ) internal onlyInitializing {
        __DLT_init_unchained(name, symbol);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __DLT_init_unchained(
        string memory name,
        string memory symbol
    ) internal onlyInitializing {
        _name = name;
        _symbol = symbol;
    }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721,ERC721URIStorage) returns (bool) {
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
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        require(spender != owner, "DLT: approval to current owner");
        _approve(owner, spender, mainId, subId, amount);
        return true;
    }

    /**
     * @dev See {DLT-setApprovalForAll}.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override(ERC721,IERC721,IDLTUpgradeable){
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
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least `amount`.
     */
    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) public virtual returns (bool) {
        _safeTransferFrom(sender, recipient, mainId, subId, amount, "");
        return true;
    }

    function safeTransferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount,
        bytes memory data
    ) public virtual returns (bool) {
        _safeTransferFrom(sender, recipient, mainId, subId, amount, data);
        return true;
    }

    function safeBatchTransferFrom(
        address sender,
        address recipient,
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata amounts,
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
            amounts,
            data
        );
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) public virtual returns (bool) {
        _transferFrom(sender, recipient, mainId, subId, amount);
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

    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override(ERC721,IERC721,IDLTUpgradeable) returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Safely mints `amount` in specific `subId` in specific `mainId` and transfers it to `recipient`.
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
        uint256 amount
    ) internal virtual {
        _safeMint(recipient, mainId, subId, amount, "");
    }

    /**
     * @dev Same as [`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IDLTReceiverUpgradeable-onDLTReceived} to contract recipients.
     */
    function _safeMint(
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _mint(recipient, mainId, subId, amount);
        require(
            _checkOnDLTReceived(
                address(0),
                recipient,
                mainId,
                subId,
                amount,
                data
            ),
            "DLT: transfer to non DLTReceiver implementer"
        );
    }

    /**
     * @dev Safely transfers `amount` from `subId` in specific `mainId from `sender` to `recipient`,
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
     * - `amount` sender can transfer at least his balance.
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
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _transfer(sender, recipient, mainId, subId, amount);
        require(
            _checkOnDLTReceived(sender, recipient, mainId, subId, amount, data),
            "DLT: transfer to non DLTReceiver implementer"
        );
    }

    function _safeTransferFrom(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        address spender = _msgSender();

        if (!_isApprovedOrOwner(sender, spender)) {
            _spendAllowance(sender, spender, mainId, subId, amount);
        }

        _safeTransfer(sender, recipient, mainId, subId, amount, data);
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
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(
            mainIds.length == subIds.length && mainIds.length == amounts.length,
            "DLT: mainIds, subIds and amounts length mismatch"
        );
        require(recipient != address(0), "DLT: transfer to the zero address");

        address operator = _msgSender();

        for (uint256 i = 0; i < mainIds.length; ++i) {
            uint256 mainId = mainIds[i];
            uint256 subId = subIds[i];
            uint256 amount = amounts[i];
            uint256 senderBalance = _balances[mainId][sender][subId];

            require(
                senderBalance >= amount,
                "DLT: insufficient balance for transfer"
            );
            unchecked {
                _balances[mainId][sender][subId] = senderBalance - amount;
            }
            _balances[mainId][recipient][subId] += amount;
        }

        emit TransferBatch(
            operator,
            sender,
            recipient,
            mainIds,
            subIds,
            amounts
        );
        require(
            _checkOnDLTBatchReceived(
                sender,
                recipient,
                mainIds,
                subIds,
                amounts,
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
        uint256 amount
    ) internal virtual {
        address spender = _msgSender();

        if (!_isApprovedOrOwner(sender, spender)) {
            _spendAllowance(sender, spender, mainId, subId, amount);
        }

        _transfer(sender, recipient, mainId, subId, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = _allowance(owner, spender, mainId, subId);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "DLT: insufficient allowance");
            unchecked {
                _approve(
                    owner,
                    spender,
                    mainId,
                    subId,
                    currentAllowance - amount
                );
            }
        }
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
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
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "DLT: approve from the zero address");
        require(spender != address(0), "DLT: approve to the zero address");

        _allowances[owner][spender][mainId][subId] = amount;
        emit Approval(owner, spender, mainId, subId, amount);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual override{
        require(owner != operator, "DLT: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
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
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "DLT: transfer from the zero address");
        require(recipient != address(0), "DLT: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, mainId, subId, amount, "");

        require(
            _balances[mainId][sender][subId] >= amount,
            "DLT: insufficient balance for transfer"
        );
        unchecked {
            _balances[mainId][sender][subId] -= amount;
        }

        _balances[mainId][recipient][subId] += amount;

        emit Transfer(sender, recipient, mainId, subId, amount);

        _afterTokenTransfer(sender, recipient, mainId, subId, amount, "");
    }

    /** @dev Creates `amount` tokens and assigns them to `account`
     *
     * Emits a {Transfer} event with `sender` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `amount` cannot be zero .
     */
      function mint(
         address account,
        uint256 mainId,
        uint256 subId,
        string memory name,
        uint256 amount,string memory _tokenURI)public virtual{
            _mint(account,mainId,subId,amount);
           setTokenURI(mainId,name,_tokenURI);
        }


    function setTokenURI(uint256 _assetId,string memory name, string memory assetURI) internal {
        string memory _assetURI=generateJSON(name, assetURI);
        _tokenURIs[_assetId] =_assetURI;
        _setTokenURI(_assetId, _assetURI);
    }



    function generateJSON(
        string memory name,
        string memory image
    ) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{',
                '"name": "', name, '",',
                '"image": "', image, '"',
                '}'
            )
        );
    }
 
  function tokenURI(
        uint256 _assetId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_assetId);
    
    }


function addMovie(address movieProducer,string memory movieName,uint256 _totalDepartments)public{
    movies[movieIdCounter]=Movie(movieProducer,movieIdCounter,movieName,_totalDepartments);
    mint(movieProducer,movieIdCounter,0,movieName,_totalDepartments,"");
    departmentIdCounter=1;
    departmentCount[movieIdCounter]=0;
}

function addDepartment(address departmentManager,uint256 movieId,string memory departmentName,uint256 totalEmployees)public{
    require(departmentCount[movieId]<movies[movieId].totalDepartments,"exceeds the department limit");
    //how to add metohd for not to repeat the same department adding twice
     departments[movieId][departmentIdCounter]=Departments(departmentIdCounter,movieId,departmentName,totalEmployees);
     mint(departmentManager,movieId,departmentIdCounter,departmentName,totalEmployees,"");
     employeeCount[movieId][departmentIdCounter]=0;
     employeeIdCounter=0;
     departmentCount[movieId]++;
}

function addEmployee(uint256 movieId,uint256 departmentId,address employee,string memory employeename,uint256 _salary)public{
    require(employeeCount[movieId][departmentId]<departments[movieId][departmentId].noOfEmployees,"Employee count exceeds");
    //how to   add method so that same empolyee must not be added twice
    employeeDetails[movieId][departmentId][employeeIdCounter]=Employees(employee,movieId,departmentId,_salary);
     string memory IdName=string(abi.encodePacked(employeename,movieId.toString(),departmentId.toString(),employeeIdCounter));
     //mint(employee,movieId,departmentId,IdName,_salary,"");
    employeeIdCounter++;
    employeeCount[movieId][departmentId]++;
}
    function _mint(
        address account,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "DLT: mint to the zero address");
        require(amount != 0, "DLT: mint zero amount");
           _mint(account, mainId);

        _beforeTokenTransfer(address(0), account, mainId, subId, amount, "");

        _balances[mainId][account][subId] += amount;

        emit Transfer(address(0), account, mainId, subId, amount);

        _afterTokenTransfer(address(0), account, mainId, subId, amount, "");
    }

function distributeSalary(uint256 movieId, uint256 departmentId, uint256 amount) public {
    // Check if the caller has the necessary permissions, you can customize this based on your requirements.
    require(msg.sender == movies[movieId].producer, "DLT: Caller does not have permission");

    // Calculate the salary per employee
    uint256 totalEmployees = departments[movieId][departmentId].noOfEmployees;
    require(totalEmployees > 0, "DLT: No employees in the department");
    
    uint256 salary= amount ;

    // Mint tokens for each employee in the department
    for (uint256 i = 0; i < totalEmployees; i++) {
        address employee = employeeDetails[movieId][departmentId][i].employee;
        if(employee!=address(0)){
            salary-= employeeDetails[movieId][departmentId][i].salary;
        }
    }

    // Emit an event or perform other actions as needed
    emit SalaryDistributed(movieId, departmentId, amount);
}
    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `recipient` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(
        address account,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "DLT: burn from the zero address");
        require(amount != 0, "DLT: burn zero amount");

        uint256 fromBalanceSub = _balances[mainId][account][subId];
        require(fromBalanceSub >= amount, "DLT: insufficient balance");

        _beforeTokenTransfer(account, address(0), mainId, subId, amount, "");

        unchecked {
            _balances[mainId][account][subId] -= amount;

            // Overflow not possible: amount <= fromBalanceMain <= totalSupply.
        }

        emit Transfer(account, address(0), mainId, subId, amount);

        _afterTokenTransfer(account, address(0), mainId, subId, amount, "");
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `sender` and `recipient` are both non-zero, `amount` of ``sender``'s tokens
     * will be transferred to `recipient`.
     * - when `sender` is zero, `amount` tokens will be minted for `recipient`.
     * - when `recipient` is zero, `amount` of ``sender``'s tokens will be burned.
     * - `sender` and `recipient` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `sender` and `recipient` are both non-zero, `amount` of ``sender``'s tokens
     * has been transferred to `recipient`.
     * - when `sender` is zero, `amount` tokens have been minted for `recipient`.
     * - when `recipient` is zero, `amount` of ``sender``'s tokens have been burned.
     * - `sender` and `recipient` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address sender,
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount,
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

    function _isApprovedOrOwner(
        address sender,
        address spender
    ) internal view virtual returns (bool) {
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
        uint256 amount,
        bytes memory data
    ) private returns (bool) {
        if (recipient.code.length > 0) {
            try
                IDLTReceiverUpgradeable(recipient).onDLTReceived(
                    _msgSender(),
                    sender,
                    mainId,
                    subId,
                    amount,
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
        uint256[] memory amounts,
        bytes memory data
    ) private returns (bool) {
        if (recipient.code.length > 0) {
            try
                IDLTReceiverUpgradeable(recipient).onDLTBatchReceived(
                    _msgSender(),
                    sender,
                    mainIds,
                    subIds,
                    amounts,
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
