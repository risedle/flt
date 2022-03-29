// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IfERC20 } from "./interfaces/IfERC20.sol";
import { IUniswapAdapter } from "./interfaces/IUniswapAdapter.sol";
import { IRariFusePriceOracleAdapter } from "./interfaces/IRariFusePriceOracleAdapter.sol";
import { RiseToken } from "./RiseToken.sol";

/**
 * @title Rise Token Factory
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Factory contract to create new Rise Token
 */
contract RiseTokenFactory is Ownable {
    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice List of created tokens
    address[] public tokens;

    /// @notice To make sure Rise Token only created once
    mapping(address => mapping(address => address)) public getToken;

    /// @notice Fee recipient
    address public feeRecipient;

    /// @notice Uniswap Adapter
    IUniswapAdapter public uniswapAdapter;

    /// @notice Rari Fuse Price Oracle Adapter
    IRariFusePriceOracleAdapter public oracleAdapter;


    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when new token is created
    event TokenCreated(address token, address fCollateral, address fDebt, uint256 totalTokens);

    /// @notice Event emitted when feeRecipient is updated
    event FeeRecipientUpdated(address newRecipient);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when collateral or debt token is not configured
    ///         in Uniswap Adapter
    error UniswapNotConfigured(address token);

    /// @notice Error is raised when oracle for collateral or debt token is not
    ///         configured in Rari Fuse Price Oracle Adapter
    error OracleNotConfigured(address token);

    /// @notice Error is raised when token is already exists
    error TokenExists(address token);


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(address _feeRecipient, address _uniswapAdapter, address _oracleAdapter) {
        feeRecipient = _feeRecipient;
        uniswapAdapter = IUniswapAdapter(_uniswapAdapter);
        oracleAdapter = IRariFusePriceOracleAdapter(_oracleAdapter);
    }


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Sets fee recipient
     * @param _newRecipient New fee recipient
     */
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /**
     * @notice Creates new Rise Token
     * @param _fCollateral fToken from Rari Fuse that used as collateral asset
     * @param _fDebt fToken from Rari Fuse that used as debt asset
     * @return _token The Rise Token address
     */
    function create(address _fCollateral, address _fDebt) external onlyOwner returns (address _token) {
        /// ███ Checks

        // Get the underlying assets
        address collateral = IfERC20(_fCollateral).underlying();
        address debt = IfERC20(_fDebt).underlying();

        // Check uniswap adapter
        if (!uniswapAdapter.isConfigured(collateral)) revert UniswapNotConfigured(collateral);
        if (!uniswapAdapter.isConfigured(debt)) revert UniswapNotConfigured(debt);

        // Check price oracle
        if (!oracleAdapter.isConfigured(collateral)) revert OracleNotConfigured(collateral);
        if (!oracleAdapter.isConfigured(debt)) revert OracleNotConfigured(debt);

        // Check existing token
        if (getToken[collateral][debt] != address(0)) revert TokenExists(getToken[collateral][debt]);


        /// ███ Contract deployment

        bytes memory creationCode = type(RiseToken).creationCode;
        string memory tokenName = string(abi.encodePacked(IERC20Metadata(collateral).symbol(), " 2x Long Risedle"));
        string memory tokenSymbol = string(abi.encodePacked(IERC20Metadata(collateral).symbol(), "RISE"));
        bytes memory constructorArgs = abi.encode(tokenName, tokenSymbol, address(this), _fCollateral, _fDebt);
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        bytes32 salt = keccak256(abi.encodePacked(_fCollateral, _fDebt));
        assembly {
            _token := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        getToken[_fCollateral][_fDebt] = _token;
        getToken[_fDebt][_fCollateral] = _token; // populate mapping in the reverse direction
        tokens.push(_token);

        emit TokenCreated(_token, _fCollateral, _fDebt, tokens.length);
    }

}
