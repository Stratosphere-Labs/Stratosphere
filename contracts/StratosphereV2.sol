// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./lib/Ownable.sol";
import "./lib/Janitable.sol";
import "./lib/Address.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract StratosphereV2 is ERC2771Recipient, IERC20, Ownable, Janitable {
    // ERC20Permit
    using Counters for Counters.Counter;

    mapping(address => Counters.Counter) private _nonces;

    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

    bytes32 private _CACHED_DOMAIN_SEPARATOR;
    uint256 private _CACHED_CHAIN_ID;
    address private _CACHED_THIS;

    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;
    bytes32 private _TYPE_HASH;
    // END

    // Settings for the contract (supply, taxes, ...)

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 private _totalClaimed;

    string private _name;
    string private _version;
    string private _symbol;
    uint8 private _decimals;

    uint256 public _taxFee;
    uint256 private _previousTaxFee;

    uint256 public _liquidityFee;
    uint256 private _previousLiquidityFee;

    uint256 public _rewardFee;
    uint256 private _previousRewardFee;

    mapping(address => uint256) public _personalIncineratorFee;
    uint256 public _incineratorFee;
    uint256 private _previousIncineratorFee;

    address payable public _incineratorAddress;

    uint256 public _numTokensSellToAddToLiquidity;

    mapping(address => uint256) private _bought;
    uint256 private _boughtTotal;
    uint256 private _MATICRewards;

    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => uint256) private _claimed;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isCleaned;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    mapping(address => bool) public _blacklist;

    IUniswapV2Router02 public uniswapV2Router; // Formerly immutable
    address public uniswapV2Pair; // Formerly immutable
    address public _routerAddress;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    bool public tradingEnabled;
    bool public doSwapForRouter;
    bool public _transferClaimedEnabled;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokens, uint256 poly);
    event AddedMATICReward(uint256 poly);
    event DoSwapForRouterEnabled(bool enabled);
    event TradingEnabled(bool eanbled);
    event AddMATICToRewardpPool(uint256 poly);
    event ExcludeMaxWalletToken(address indexed account, bool isExcluded);
    event ClaimedMATIC(address indexed account, uint256 matic);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    fallback() external payable {}

    receive() external payable {}

    modifier onlyJanitorOrOwner() {
        require(
            janitor() == _msgSender() || owner() == _msgSender(),
            "Caller not janitor/owner."
        );
        _;
    }

    function initialize(
        address routerAddress,
        address trustedForwarder
    ) public override(Ownable, Janitable) initializer {
        Ownable.initialize(_msgSender(), trustedForwarder);
        Janitable.initialize(_msgSender(), trustedForwarder);

        // token vars
        _tTotal = 2000 * 10 ** 6 * 10 ** 9;
        _rTotal = (MAX - (MAX % _tTotal));
        _name = "Stratosphere POLY V2";
        _version = "2";
        _symbol = "STRAT";
        _decimals = 9;

        _taxFee = 10;
        _previousTaxFee = _taxFee;

        _liquidityFee = 5;
        _previousLiquidityFee = _liquidityFee;
        _rewardFee = 30;
        _previousRewardFee = _rewardFee;
        _numTokensSellToAddToLiquidity = 100000000000000;
        _boughtTotal = 0;
        _MATICRewards = 0;

        swapAndLiquifyEnabled = true; // Toggle swap & liquify on and off
        tradingEnabled = true; // To avoid snipers
        doSwapForRouter = true; // Toggle swap & liquify on and off for transactions to / from the router
        _transferClaimedEnabled = true; // Transfer claim rights upon transfer of tokens

        // create a uniswap pair for this new token
        _routerAddress = routerAddress;
        _rOwned[_msgSender()] = _rTotal;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _routerAddress
        ); // Initialize router
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[owner()] = true; // Owner doesn't pay fees (e.g. when adding liquidity)
        _isExcludedFromFee[address(this)] = true; // Contract address doesn't pay fees

        _incineratorFee = 17;
        _previousIncineratorFee = _incineratorFee;
        _incineratorAddress = payable(
            0xC08AF4fb5Dc4E1bb707a384dBA75011028cD67e1
        );

        emit Transfer(address(0), _msgSender(), _tTotal);

        //ERC20 Permit
        bytes32 hashedName = keccak256(bytes(_name));
        bytes32 hashedVersion = keccak256(bytes(_version));
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(
            typeHash,
            hashedName,
            hashedVersion
        );
        _CACHED_THIS = address(this);
        _TYPE_HASH = typeHash;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function boughtBy(address account) public view returns (uint256) {
        return _bought[account];
    }

    function boughtTotal() public view returns (uint256) {
        return _boughtTotal;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(!_blacklist[_msgSender()], "Blacklisted");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function setTrustedForwarder(
        address _trustedForwarder
    ) public override(Ownable, Janitable) onlyJanitorOrOwner {
        _setTrustedForwarder(_trustedForwarder);
        Ownable.setTrustedForwarder(_trustedForwarder);
        Janitable.setTrustedForwarder(_trustedForwarder);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(!_blacklist[sender], "Blacklisted");
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function isCleaned(address account) public view returns (bool) {
        return _isCleaned[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded");
        (uint256 rAmount, , , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rTotal = _rTotal - rAmount;
        _tFeeTotal = _tFeeTotal + tAmount;
    }

    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount > supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount > reflections");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndRewards,
            uint256 tIncinerator
        ) = _getValues(tAmount);
        _transferClaimed(sender, recipient, tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidityAndRewards(tLiquidityAndRewards, sender);
        _takeIncinerator(tIncinerator, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function clean(address account) public onlyOwner {
        _isCleaned[account] = true;
    }

    function unclean(address account) public onlyOwner {
        _isCleaned[account] = false;
    }

    function addToBlacklist(address account) public onlyOwner {
        _blacklist[account] = true;
    }

    function removeFromBlacklist(address account) public onlyOwner {
        _blacklist[account] = false;
    }

    function setIncineratorAddress(address account) public onlyOwner {
        _incineratorAddress = payable(account);
    }

    function setIncineratorFeePromille(
        uint256 incineratorFee
    ) external onlyOwner {
        _incineratorFee = incineratorFee;
    }

    function setPersonalIncineratorFeePromille(
        address account,
        uint256 incineratorFee
    ) external onlyOwner {
        _personalIncineratorFee[account] = incineratorFee;
    }

    function setTaxFeePromille(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function setRewardFeePromille(uint256 rewardFee) external onlyOwner {
        _rewardFee = rewardFee;
    }

    function setLiquidityFeePromille(uint256 liquidityFee) external onlyOwner {
        _liquidityFee = liquidityFee;
    }

    function setNumTokensSellToAddToLiquidity(
        uint256 numTokensSellToAddToLiquidity
    ) external onlyJanitorOrOwner {
        _numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyJanitorOrOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setTransferClaimedEnabled(
        bool _enabled
    ) public onlyJanitorOrOwner {
        _transferClaimedEnabled = _enabled;
    }

    function setTradingEnabled(bool _enabled) public onlyOwner {
        tradingEnabled = _enabled;
        emit TradingEnabled(_enabled);
    }

    function enableTrading() public onlyJanitorOrOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    function setDoSwapForRouter(bool _enabled) public onlyJanitorOrOwner {
        doSwapForRouter = _enabled;
        emit DoSwapForRouterEnabled(_enabled);
    }

    function setRouterAddress(address routerAddress) public onlyJanitorOrOwner {
        _routerAddress = routerAddress;
    }

    function setPairAddress(address pairAddress) public onlyJanitorOrOwner {
        uniswapV2Pair = pairAddress;
    }

    function migrateRouter(address routerAddress) external onlyJanitorOrOwner {
        setRouterAddress(routerAddress);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _routerAddress
        ); // Initialize router
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(
            address(this),
            _uniswapV2Router.WETH()
        );
        if (uniswapV2Pair == address(0))
            uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
                .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(
        uint256 tAmount
    )
        private
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndRewards,
            uint256 tIncinerator
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidityAndRewards,
            tIncinerator,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidityAndRewards,
            tIncinerator
        );
    }

    function _getTValues(
        uint256 tAmount
    ) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidityAndRewards = calculateLiquidityAndRewards(tAmount);
        uint256 tIncinerator = calculateIncineratorFee(tAmount);
        uint256 tTransferAmount = tAmount -
            tFee -
            tLiquidityAndRewards -
            tIncinerator;
        return (tTransferAmount, tFee, tLiquidityAndRewards, tIncinerator);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidityAndRewards,
        uint256 tIncinerator,
        uint256 currentRate
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidityAndRewards = tLiquidityAndRewards * currentRate;
        uint256 rIncinerator = tIncinerator * currentRate;
        uint256 rTransferAmount = rAmount -
            rFee -
            rLiquidityAndRewards -
            rIncinerator;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeIncinerator(uint256 tIncinerator, address from) private {
        if (tIncinerator == 0) return;
        uint256 currentRate = _getRate();
        uint256 rIncinerator = tIncinerator * currentRate;
        _rOwned[_incineratorAddress] =
            _rOwned[_incineratorAddress] +
            rIncinerator;
        if (_isExcluded[_incineratorAddress])
            _tOwned[_incineratorAddress] =
                _tOwned[_incineratorAddress] +
                tIncinerator;
        emit Transfer(from, _incineratorAddress, tIncinerator);
    }

    function _takeLiquidityAndRewards(
        uint256 tLiquidityAndRewards,
        address from
    ) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidityAndRewards = tLiquidityAndRewards * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidityAndRewards;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] =
                _tOwned[address(this)] +
                tLiquidityAndRewards;
        emit Transfer(from, address(this), tLiquidityAndRewards);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return (_amount * _taxFee) / 10 ** 3;
    }

    function calculateLiquidityFee(
        uint256 _amount
    ) private view returns (uint256) {
        return (_amount * _liquidityFee) / (10 ** 3);
    }

    function calculateIncineratorFee(
        uint256 _amount
    ) private view returns (uint256) {
        uint256 fee = _incineratorFee;
        if (_msgSender() == _incineratorAddress) {
            fee = 0;
        } else if (_personalIncineratorFee[_msgSender()] > 0) {
            fee = _personalIncineratorFee[_msgSender()];
        }
        return (_amount * fee) / (10 ** 3);
    }

    function calculateLiquidityAndRewards(
        uint256 _amount
    ) private view returns (uint256) {
        uint256 fee = _liquidityFee + _rewardFee;
        return (_amount * fee) / 10 ** 3;
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0 && _rewardFee == 0) return;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousIncineratorFee = _incineratorFee;
        _previousRewardFee = _rewardFee;
        _taxFee = 0;
        _liquidityFee = 0;
        _incineratorFee = 0;
        _rewardFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _rewardFee = _previousRewardFee;
        _incineratorFee = _previousIncineratorFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(
            owner != address(0) && spender != address(0),
            "ERC20: approve zero address"
        );
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function sweep(address payable recipient) public onlyJanitorOrOwner {
        (bool success, ) = recipient.call{value: address(this).balance}("");
        require(success, "Clean failed");
        _MATICRewards = 0;
    }

    function addMATICToReward() public payable onlyJanitorOrOwner {
        require(msg.value >= 0);
        _MATICRewards = _MATICRewards + msg.value;
        emit AddMATICToRewardpPool(msg.value);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(
            from != address(0) && to != address(0),
            "ERC20: transfer zero address"
        );
        require(!_isCleaned[from]);
        require(amount > 0, "Transfer <= zero");
        if (
            from != owner() &&
            to != owner() &&
            from != janitor() &&
            to != janitor()
        ) {
            require(tradingEnabled, "Trading not enabled");
        }
        if (from == uniswapV2Pair) {
            _boughtTotal = _boughtTotal + amount;
            _bought[to] = _bought[to] + amount;
        } else if (to == uniswapV2Pair) {
            _boughtTotal = _boughtTotal - _bought[from];
            _bought[from] = 0;
        }
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >=
            _numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            (doSwapForRouter ||
                (from != _routerAddress && to != _routerAddress)) &&
            swapAndLiquifyEnabled
        ) {
            swap(contractTokenBalance); // add liquidity
        }
        bool takeFee = true;
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swap(uint256 contractTokenBalance) private lockTheSwap {
        uint256 totalFee = _liquidityFee + _rewardFee;
        uint256 tokensForLiquidity = ((contractTokenBalance * _liquidityFee) /
            totalFee) / 2;
        if (tokensForLiquidity < contractTokenBalance) {
            // sell tokens
            uint256 tokensToSell = contractTokenBalance - tokensForLiquidity;
            uint256 initialBalance = address(this).balance;
            swapTokensForMATIC(tokensToSell);
            uint256 acquiredMATIC = address(this).balance - initialBalance;
            // calculate share for liquidity or rewards
            uint256 polyForLiquidity = (acquiredMATIC * tokensForLiquidity) /
                tokensToSell;
            uint256 polyForRewards = acquiredMATIC - polyForLiquidity;
            // update rewards
            _MATICRewards = _MATICRewards + polyForRewards;
            // add liquidity
            addLiquidity(tokensForLiquidity, polyForLiquidity);
            emit SwapAndLiquify(tokensForLiquidity, polyForLiquidity);
        }
    }

    function swapTokensForMATIC(uint256 tokenAmount) private {
        // Generate the polyswap pair path of token -> MATIC
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens( // Make the swap
            tokenAmount,
            0, // accept any amount of MATIC
            path,
            address(this),
            block.timestamp
        );
    }

    function swapMATICForToken(
        uint256 polyAmount,
        address recipient,
        address token
    ) internal returns (uint256) {
        require(!_blacklist[recipient], "You are blacklisted from swaping");

        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(token);

        uint256 balanceBefore = IERC20(token).balanceOf(recipient);

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: polyAmount
        }(0, path, recipient, block.timestamp);

        uint256 tokenAmount = IERC20(token).balanceOf(recipient) -
            balanceBefore;
        return tokenAmount;
    }

    function addLiquidity(uint256 tokenAmount, uint256 polyAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: polyAmount}( // Add liqudity
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            janitor(),
            block.timestamp
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        uint256 oldTaxFee = _taxFee;
        uint256 oldLiquidityFee = _liquidityFee;
        if (!takeFee) {
            removeAllFee();
        }
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        if (!takeFee) restoreAllFee();
        _taxFee = oldTaxFee;
        _liquidityFee = oldLiquidityFee;
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndRewards,
            uint256 tIncinerator
        ) = _getValues(tAmount);
        _transferClaimed(sender, recipient, tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidityAndRewards(tLiquidityAndRewards, sender);
        _takeIncinerator(tIncinerator, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndRewards,
            uint256 tIncinerator
        ) = _getValues(tAmount);
        _transferClaimed(sender, recipient, tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidityAndRewards(tLiquidityAndRewards, sender);
        _takeIncinerator(tIncinerator, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndRewards,
            uint256 tIncinerator
        ) = _getValues(tAmount);
        _transferClaimed(sender, recipient, tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidityAndRewards(tLiquidityAndRewards, sender);
        _takeIncinerator(tIncinerator, sender);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function totalRewards() public view returns (uint256) {
        return _MATICRewards;
    }

    function rewards(address recipient) public view returns (uint256) {
        uint256 total = _tTotal -
            balanceOf(0x000000000000000000000000000000000000dEaD);
        uint256 brut = (_MATICRewards * balanceOf(recipient)) / total;
        if (brut > _claimed[recipient]) return brut - _claimed[recipient];
        return 0;
    }

    function claimed(address recipient) public view returns (uint256) {
        return _claimed[recipient];
    }

    function _transferClaimed(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        if (_transferClaimedEnabled) {
            require(balanceOf(sender) > 0);
            uint256 proportionClaimed = (_claimed[sender] * (tAmount)) /
                balanceOf(sender);
            if (_claimed[sender] > proportionClaimed)
                _claimed[sender] = _claimed[sender] - proportionClaimed;
            else _claimed[sender] = 0;
            _claimed[recipient] = _claimed[recipient] + proportionClaimed;
        }
    }

    function claim() public {
        require(!_blacklist[_msgSender()], "Blacklisted");
        if (_boughtTotal > 0) {
            uint256 total = _tTotal -
                balanceOf(0x000000000000000000000000000000000000dEaD);
            uint256 brut = (_MATICRewards * balanceOf(_msgSender())) / total;
            require(brut > _claimed[_msgSender()], "Not enough to claim");
            uint256 toclaim = brut - _claimed[_msgSender()];
            _claimed[_msgSender()] = _claimed[_msgSender()] + toclaim;
            (bool success, ) = _msgSender().call{value: toclaim}("");
            require(success, "Claim failed");
            _totalClaimed = _totalClaimed + toclaim;
            emit ClaimedMATIC(_msgSender(), toclaim);
        }
    }

    function claimToken(address token) public {
        require(!_blacklist[_msgSender()], "You are blacklisted");
        if (_boughtTotal > 0) {
            uint256 total = _tTotal -
                balanceOf(0x000000000000000000000000000000000000dEaD);
            uint256 brut = (_MATICRewards * balanceOf(_msgSender())) / (total);
            require(brut > _claimed[_msgSender()], "Not enough to claim");
            uint256 toclaim = brut - _claimed[_msgSender()];
            _claimed[_msgSender()] = _claimed[_msgSender()] + toclaim;
            uint256 tokenAmount = swapMATICForToken(
                toclaim,
                _msgSender(),
                token
            );
            require(tokenAmount != 0, "Claim failed");
            _totalClaimed = _totalClaimed + toclaim;
            emit ClaimedMATIC(_msgSender(), toclaim);
        }
    }

    function reinvest() public {
        require(!_blacklist[_msgSender()], "Blacklisted");
        if (_boughtTotal > 0) {
            uint256 total = _tTotal -
                balanceOf(0x000000000000000000000000000000000000dEaD);
            uint256 brut = (_MATICRewards * balanceOf(_msgSender())) / total;
            require(brut > _claimed[_msgSender()], "Not enough to claim");
            uint256 toclaim = brut - _claimed[_msgSender()];
            _claimed[_msgSender()] = _claimed[_msgSender()] + toclaim;
            uint256 tokenAmount = swapMATICForToken(
                toclaim,
                _msgSender(),
                address(this)
            );
            require(tokenAmount != 0, "Claim failed");
            _totalClaimed = _totalClaimed + toclaim;
        }
    }

    function totalClaimed() public view returns (uint256) {
        return _totalClaimed;
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }

    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner].current();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _useNonce(
        address owner
    ) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    //EIP 712
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (
            address(this) == _CACHED_THIS && block.chainid == _CACHED_CHAIN_ID
        ) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return
                _buildDomainSeparator(
                    _TYPE_HASH,
                    _HASHED_NAME,
                    _HASHED_VERSION
                );
        }
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    block.chainid,
                    address(this)
                )
            );
    }

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}
