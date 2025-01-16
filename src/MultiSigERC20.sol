// src/MyERC20v2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title MultiSigERC20
 * @notice A minimal ERC20 token with:
 *         - A single "pauser" address for pause/unpause (centralized)
 *         - A 4-of-6 multiSig for mint/burn.
 *         While paused, all transfers/approvals are disabled.
 */
contract MultiSigERC20 {
    // ========== ERC20 Metadata ==========
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    // ========== Balances & Supply ==========
    uint256 public totalSupply;
    mapping(address => uint256) private _balances;

    // ========== Allowances ==========
    mapping(address => mapping(address => uint256)) private _allowances;

    // ========== Pausable ==========
    bool public paused;
    address public pauser;  // single centralized address for pause/unpause

    // ========== MultiSig for Mint/Burn ==========
    address public multiSigMintBurn; // 4-of-6

    // ========== Events ==========
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Paused();
    event Unpaused();
    event PauserChanged(address indexed oldPauser, address indexed newPauser);

    // ========== Constructor ==========
    /**
     * @param _name e.g. "MyToken"
     * @param _symbol e.g. "MTK"
     * @param _decimals e.g. 18
     * @param _multiSigMintBurn The 4-of-6 multisig controlling mint/burn
     * @param _pauser A normal address that can pause/unpause
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _multiSigMintBurn,
        address _pauser
    ) {
        require(_multiSigMintBurn != address(0), "Zero multiSig");
        require(_pauser != address(0), "Zero pauser");

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        multiSigMintBurn = _multiSigMintBurn;
        pauser = _pauser;
        paused = false;
    }

    // ========== Standard ERC20 ==========

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(!paused, "Token paused");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(!paused, "Token paused");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(!paused, "Token paused");
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Transfer exceeds allowance");
        _allowances[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    // ========== Mint & Burn via 4-of-6 multiSig ==========

    function mint(address to, uint256 amount) external {
        require(!paused, "Token paused");
        require(msg.sender == multiSigMintBurn, "Only multiSig can mint");
        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(!paused, "Token paused");
        require(msg.sender == multiSigMintBurn, "Only multiSig can burn");
        uint256 bal = _balances[from];
        require(bal >= amount, "Burn exceeds balance");
        _balances[from] = bal - amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ========== Pause / Unpause by central address ==========

    function pause() external {
        require(msg.sender == pauser, "Only pauser can pause");
        require(!paused, "Already paused");
        paused = true;
        emit Paused();
    }

    function unpause() external {
        require(msg.sender == pauser, "Only pauser can unpause");
        require(paused, "Not paused");
        paused = false;
        emit Unpaused();
    }

    /**
     * @dev Optionally let the pauser be changed by the current pauser
     */
    function changePauser(address newPauser) external {
        require(msg.sender == pauser, "Only current pauser");
        require(newPauser != address(0), "Zero newPauser");
        address old = pauser;
        pauser = newPauser;
        emit PauserChanged(old, newPauser);
    }

    // ========== Internal Transfer ==========

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "transfer from zero");
        require(to != address(0),   "transfer to zero");

        uint256 senderBal = _balances[from];
        require(senderBal >= amount, "Transfer exceeds balance");

        _balances[from] = senderBal - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }
}