// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Listing.sol";
import "./interfaces/IWETH.sol";
import "./TheRareAntiquitiesToken.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conforms
 * the base architecture for crowdsales. It is *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
contract Crowdsale is Context, ReentrancyGuard, Listing {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The token being sold
    IERC20 private _token;

    // Router address
    // address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public immutable uniswapV2Router;

    // Address where funds are collected
    address payable private _wallet;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    // Amount of wei raised
    uint256 private _preIcoWeiRaised;
    uint256 private _weiRaised;

    uint256 private preIcoSold;
    uint256 private icoSold;

    // Maximum Goal or Hard Cap (ETH)
    uint256 private _hardCap = 1000 ether;

    mapping(address => uint256) public deposited;

    // Enums
    //========================
    // Crowdsale Stages
    enum CrowdsaleStage {
        PREICO,
        ICO
    }

    enum State {
        Active,
        Refunding,
        Closed
    }

    //========================

    CrowdsaleStage public stage = CrowdsaleStage.PREICO; // By default it's Pre ICO

    State public state = State.Active;

    // PRE-ICO Start Date (14th August)
    // 1628899200
    uint256 private _preIcoStartDate = 1628899200;

    // PRE-ICO End Date (27th August)
    // 1630047600
    uint256 private _preIcoEndDate = 1630047600;

    // PRE-ICO Tokens available (15%)
    // 75000000000 ether
    uint256 private _preIcoTokens = 75000000000 ether;

    // ICO Start Date (28th August)
    // 1630108800
    uint256 private _icoStartDate = 1630108800;

    // ICO End Date (28th September)
    // 1632787200
    uint256 private _icoEndDate = 1632787200;

    // ICO Tokens available (70%)
    uint256 private _icoTokens = 350000000000 ether;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    event EthRefunded(string text);

    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);

    //   Modifiers
    //================
    modifier checkWhitelist(address account) {
        if (stage == CrowdsaleStage.PREICO && !whitelisted(account))
            revert("Crowdsale: NOT_WHITELISTED");
        _;
    }

    modifier checkBlacklist(address account) {
        if (stage == CrowdsaleStage.ICO && blacklisted(account))
            revert("Crowdsale: BLACKLISTED");
        _;
    }

    modifier checkPreIcoTime() {
        if (
            (stage == CrowdsaleStage.PREICO) &&
            (block.timestamp < _preIcoStartDate)
        ) revert("Crowdsale: PRE_ICO_NOT_STARTED");
        if (
            (stage == CrowdsaleStage.PREICO) &&
            (block.timestamp > _preIcoEndDate)
        ) revert("Crowdsale: PRE_ICO_ENDED");
        _;
    }

    modifier checkIcoTime() {
        if ((stage == CrowdsaleStage.ICO) && (block.timestamp < _icoStartDate))
            revert("Crowdsale: ICO_NOT_STARTED");
        if ((stage == CrowdsaleStage.ICO) && (block.timestamp > _icoEndDate))
            revert("Crowdsale: ICO_ENDED");
        _;
    }

    modifier checkZeroAddress(address account) {
        require(account != address(0), "Crowdsale: ZERO_ADDRESS");
        _;
    }

    //==================

    /**
     * @dev The rate is the conversion between wei and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
     * @param tokenRate Number of token units a buyer gets per wei
     * @param walletAddress Address where collected funds will be forwarded to
     * @param crowdsaleToken Address of the token being sold
     */
    constructor(
        uint256 tokenRate,
        IERC20 crowdsaleToken,
        address payable walletAddress,
        address router
    ) {
        require(tokenRate > 0, "Crowdsale: INVALID_RATE");
        require(walletAddress != address(0), "Crowdsale: ZERO_ADDRESS");
        require(
            address(crowdsaleToken) != address(0),
            "Crowdsale: ZERO_ADDRESS"
        );

        _rate = tokenRate;
        _wallet = walletAddress;
        _token = crowdsaleToken;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Router = _uniswapV2Router;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive() external payable {
        buyTokens(_msgSender());
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per wei.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of wei raised.
     */
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }

    function hasEnded() public view returns (bool) {
        return block.timestamp > _icoEndDate;
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary)
        public
        payable
        nonReentrant
        checkZeroAddress(beneficiary)
        checkWhitelist(beneficiary)
        checkBlacklist(beneficiary)
        checkPreIcoTime
        checkIcoTime
    {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        if (
            (stage == CrowdsaleStage.PREICO) &&
            (preIcoSold.add(tokens) > _preIcoTokens)
        ) {
            payable(msg.sender).transfer(msg.value);
            // Refund them
            emit EthRefunded("PREICO_REACHED_LIMIT");
            return;
        } else if (
            (stage == CrowdsaleStage.ICO) && (icoSold.add(tokens) > _icoTokens)
        ) {
            payable(msg.sender).transfer(msg.value);
            // Refund them
            emit EthRefunded("ICO_REACHED_LIMIT");
            return;
        }

        if (stage == CrowdsaleStage.PREICO) {
            _preIcoWeiRaised = _preIcoWeiRaised.add(weiAmount);
            preIcoSold = preIcoSold.add(tokens);
        }

        if (stage == CrowdsaleStage.ICO) {
            icoSold = icoSold.add(tokens);
        }

        // update state
        _weiRaised = _weiRaised.add(weiAmount);

        // 2% Antiquities Tax on buys
        uint256 tokenPercentage = tokens.mul(2).div(100);
        tokens = tokens.sub(tokenPercentage);

        _token.safeTransfer(_wallet, tokenPercentage);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        _updatePurchasingState(beneficiary, weiAmount);

        // _forwardFunds();
        _postValidatePurchase(beneficiary, weiAmount);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, weiAmount);
     *     require(weiRaised().add(weiAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
    {
        require(weiAmount != 0, "Crowdsale: ZERO_AMOUNT");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        require(
            _weiRaised.add(weiAmount) <= _hardCap,
            "Crowdsale: MAX_GOAL_REACHED"
        );
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _postValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.safeTransfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
    {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param weiAmount Value in wei involved in the purchase
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount)
        internal
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        returns (uint256)
    {
        return weiAmount.mul(_rate).div(10**18);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }

    // Crowdsale Stage Management
    // =========================================================

    // Change Crowdsale Stage. Available Options: PreICO, ICO
    function setCrowdsaleStage(uint256 value) public {
        CrowdsaleStage _stage;

        if (uint256(CrowdsaleStage.PREICO) == value) {
            _stage = CrowdsaleStage.PREICO;
            setCurrentRate(100 ether);
        } else if (uint256(CrowdsaleStage.ICO) == value) {
            _stage = CrowdsaleStage.ICO;
            _icoTokens = _icoTokens + (_preIcoTokens - preIcoSold);
            setCurrentRate(200 ether);
        }
        stage = _stage;
    }

    /**
     * Get current stage
     */

    function getCurrentStage() public view returns (uint256) {
        return uint256(stage);
    }

    // Change the current rate
    function setCurrentRate(uint256 value) private {
        _rate = value;
    }

    function finish() public onlyOwner {
        require(hasEnded(), "Crowdsale: ICO_ENDED");
        uint256 tokenAmount = _token.balanceOf(address(this)).mul(100).div(60); // 60 %
        uint256 ethAmount = address(this).balance.mul(400).div(1000); // 40 %

        address weth = uniswapV2Router.WETH();
        IWETH(weth).deposit{value: ethAmount}();

        require(_token.approve(address(uniswapV2Router), ~uint256(0)));
        require(IWETH(weth).approve(address(uniswapV2Router), ~uint256(0)));
        
        uint256 liquidity;
        // add the liquidity
        (, , liquidity) = uniswapV2Router.addLiquidity(
            address(_token),
            weth,
            tokenAmount.mul(3).div(100),
            ethAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _wallet,
            block.timestamp
        );
        IWETH(weth).transfer(_wallet, IWETH(weth).balanceOf(address(this)));
        _token.transfer(_wallet, _token.balanceOf(address(this)));
    }
}
