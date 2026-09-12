// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";

interface IV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
}

interface IV3OpenFeeAdapter {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    function collect(CollectParams[] calldata collectParams) external returns (uint256[2][] memory);
}

interface IFirepit {
    // `Currency` in the real contract is a user-defined value type over `address`.
    function release(uint256 nonce, address[] calldata assets, address recipient) external;
    function nonce() external view returns (uint256);
    function threshold() external view returns (uint256);
}

/// Sells whatever it holds into USD₮0, one chunk at a time, always through
/// whichever route currently quotes best. Quotes come from really executing the
/// swaps inside a call that reverts afterwards.
contract Seller {
    uint160 constant MIN_SQRT = 4295128739 + 1;
    uint160 constant MAX_SQRT = 1461446703485210103287083490964962946475881748399 - 1;

    function uniswapV3SwapCallback(int256 a0, int256 a1, bytes calldata data) external {
        address tokenIn = abi.decode(data, (address));
        uint256 owed = a0 > 0 ? uint256(a0) : uint256(a1);
        IERC20(tokenIn).transfer(msg.sender, owed);
    }

    function _swap(address pool, address tokenIn, uint256 amountIn) internal returns (address tokenOut, uint256 out) {
        address t0 = IV3Pool(pool).token0();
        bool zeroForOne = tokenIn == t0;
        tokenOut = zeroForOne ? IV3Pool(pool).token1() : t0;
        (int256 a0, int256 a1) =
            IV3Pool(pool).swap(address(this), zeroForOne, int256(amountIn), zeroForOne ? MIN_SQRT : MAX_SQRT, abi.encode(tokenIn));
        out = uint256(-(zeroForOne ? a1 : a0));
    }

    function _run(address[] memory path, address tokenIn, uint256 amount) internal returns (uint256) {
        for (uint256 i; i < path.length; i++) {
            (tokenIn, amount) = _swap(path[i], tokenIn, amount);
        }
        return amount;
    }

    function simulate(address[] memory path, address tokenIn, uint256 amount) external {
        require(msg.sender == address(this));
        uint256 out = _run(path, tokenIn, amount);
        assembly {
            mstore(0, out)
            revert(0, 32)
        }
    }

    function _quote(address[] memory path, address tokenIn, uint256 amount) internal returns (uint256) {
        try this.simulate(path, tokenIn, amount) {}
        catch (bytes memory r) {
            if (r.length == 32) return abi.decode(r, (uint256));
        }
        return 0;
    }

    function sell(address tokenIn, address[][] memory routes, uint256 chunks) external {
        uint256 total = IERC20(tokenIn).balanceOf(address(this));
        if (total == 0) return;
        for (uint256 c; c < chunks; c++) {
            uint256 amount = c == chunks - 1 ? IERC20(tokenIn).balanceOf(address(this)) : total / chunks;
            uint256 best;
            uint256 bestOut;
            for (uint256 r; r < routes.length; r++) {
                uint256 q = _quote(routes[r], tokenIn, amount);
                if (q > bestOut) (best, bestOut) = (r, q);
            }
            if (bestOut == 0) break;
            _run(routes[best], tokenIn, amount);
        }
    }

    function sweep(address token, address to) external {
        IERC20(token).transfer(to, IERC20(token).balanceOf(address(this)));
    }
}

contract Firepit is Test {
    address user = vm.envAddress("USER_ADDRESS");
    address constant UNI = 0x57FB37d035e6Ad0E687E0a50dC3F515691deB815;
    address constant USDT = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;

    // Uniswap fee infrastructure on X Layer (github.com/Uniswap/protocol-fees README)
    address constant TOKEN_JAR = 0x8Dd8B6D56e4a4A158EDbBfE7f2f703B8FFC1a754;
    address constant FIREPIT = 0xe122E231cb52aea99690963Fd73E91e33E97468f; // OptimismBridgedResourceFirepit
    address constant V3_FEE_ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7; // V3OpenFeeAdapter

    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant USDC = 0x74b7F16337b8972027F6196A17a631aC6dE26d22;
    address constant USDT_OLD = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d;
    address constant WETH = 0x5A77f1443D16ee5761d310e38b62f77f726bC71c;
    address constant XBTC = 0xb7C00000bcDEeF966b20B3D884B98E64d2b06b4f;
    address constant XETH = 0xE7B000003A45145decf8a28FC755aD5eC5EA025A;
    address constant XSOL = 0x505000008DE8748DBd4422ff4687a4FC9bEba15b;
    address constant USDG = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;

    // Uniswap V3 pools used for selling
    address constant OKB_USDT0_100 = 0x9e485CC2Ec10E87A9B6e58602889Df392B7F6453;
    address constant OKB_USDT0_500 = 0xe3BE6A0137f1b0602Fc1a4841686f43B340a5082;
    address constant OKB_USDT0_3000 = 0x63d62734847E55A266FCa4219A9aD0a02D5F6e02;
    address constant USDG_USDT0_100 = 0x0cBe0dBE1400e57f371a38BD3b9bC80F7C3676dA;
    address constant XBTC_USDT0_100 = 0x6CF6A073dDdd6fdD74b1b9f149621E85f01AACb9;
    address constant XBTC_USDT0_500 = 0x5fcFb33C9AB1665FeE892eB2aF163e863a874D73;
    address constant XETH_USDT0_500 = 0x77ef18adF35f62B2Ad442e4370cDbC7fe78B7dcC;
    address constant XSOL_USDT0_500 = 0x4651300221f345a4c6F566079BD1DDC291049c7d;
    address constant XBTC_XETH_500 = 0xf845C41c0683cE99B8c1F36c46B2D93E1533470c;
    address constant XETH_XSOL_500 = 0xc1382e9eb8F3Df11D348D1DCcA34e246690122A2;
    address constant XETH_USDG_500 = 0x6E18CEbFb9C5BBcf127b97a6daB026E941FfF6D5;
    address constant XSOL_USDG_500 = 0x1284d2df2bF7DaC317D219d055Bd16F8259E06Df;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68413600);
        vm.etch(0x4200000000000000000000000000000000000010, hex"60006000f3");
        deal(UNI, user, 2000e18);
    }

    function test_Solution() public {
        vm.startPrank(user);

        // 1. The TokenJar is empty: the protocol fees are still inside the V3 pools.
        //    V3OpenFeeAdapter.collect is permissionless and sends them to the jar.
        address[34] memory feePools = [
            0x92Ae4136f5F141F9d20eAa0c3533f48c21Fa8580, 0x3c2a3E37A6A905b3308861222a92fF2bE2d6DA62,
            0x63d62734847E55A266FCa4219A9aD0a02D5F6e02, 0x5fcFb33C9AB1665FeE892eB2aF163e863a874D73,
            0x9e485CC2Ec10E87A9B6e58602889Df392B7F6453, 0xA10F7cE05b9149A3c91261D4dbb13FBF8F632a0f,
            0x93B2e507FfFc810E35e2981EFDEE68dC1377C430, 0xd810D4d68e7d6Ec9Bf0a841510910D4cbced0c2E,
            0xe3BE6A0137f1b0602Fc1a4841686f43B340a5082, 0x77ef18adF35f62B2Ad442e4370cDbC7fe78B7dcC,
            0x4651300221f345a4c6F566079BD1DDC291049c7d, 0x849aea45a38e0EE2459bE4CEc52cb5D73bFC5761,
            0xbb7FC8f01E84FbCf8Cd3C3F2d54d6497bFAd1693, 0x0cBe0dBE1400e57f371a38BD3b9bC80F7C3676dA,
            0x84d4DbEebFf5F77c63F36bD0dCb18121Aa9aC8fc, 0x97Bb2A4EA57B1A20D3b237B2325f56EFe25e4cE0,
            0x1200E29A106F9e1eE5334D741A1f26346AA49aF2, 0xf845C41c0683cE99B8c1F36c46B2D93E1533470c,
            0x514735D8CEfca20aabed2378FC0285E46a471232, 0x8bA178411AD22D612207588A0703417010998E65,
            0x01Cd955cba093127A5f6f8c7DED4fB773e150761, 0x5d7E3Ad08B0C52e460787677B0632Cd024Df437C,
            0xb864F203Fc61AceA1F4c98cf80a6E59132e079AF, 0x6D8CBF53b42195c2e924087cA1Ac9BBD2eca6042,
            0x637986A6cEe97e1F3E3A9A2B01a01c6327da0869, 0x6CF6A073dDdd6fdD74b1b9f149621E85f01AACb9,
            0x520F8c07A529FFb5230e76bCb8EA553D664e5b76, 0xc1382e9eb8F3Df11D348D1DCcA34e246690122A2,
            0x6E18CEbFb9C5BBcf127b97a6daB026E941FfF6D5, 0x1284d2df2bF7DaC317D219d055Bd16F8259E06Df,
            0x1bE3a8c2ecDba107d73A6C5f129dcf2aE0bfCD7D, 0xCb56d31f1382eF11Cd497c940E604aD0Bb882849,
            0x645d981a004036346C7F44c53F569580d383F29C, 0x7b133a27f913355D7fD26fa2F5bB4a61978Ee2e9
        ];
        IV3OpenFeeAdapter.CollectParams[] memory params = new IV3OpenFeeAdapter.CollectParams[](feePools.length);
        for (uint256 i; i < feePools.length; i++) {
            params[i] = IV3OpenFeeAdapter.CollectParams(feePools[i], type(uint128).max, type(uint128).max);
        }
        IV3OpenFeeAdapter(V3_FEE_ADAPTER).collect(params);
        console.log("USDT0 in jar after collect: %6e", IERC20(USDT).balanceOf(TOKEN_JAR));
        console.log("OKB in jar after collect:   %18e", IERC20(WOKB).balanceOf(TOKEN_JAR));
        console.log("xETH in jar after collect:  %18e", IERC20(XETH).balanceOf(TOKEN_JAR));
        console.log("xSOL in jar after collect:  %9e", IERC20(XSOL).balanceOf(TOKEN_JAR));
        console.log("xBTC in jar after collect:  %8e", IERC20(XBTC).balanceOf(TOKEN_JAR));
        console.log("USDG in jar after collect:  %6e", IERC20(USDG).balanceOf(TOKEN_JAR));

        // 2. Burn 2,000 UNI through the Firepit; the jar's contents go to our seller contract.
        Seller seller = new Seller();
        address[] memory assets = new address[](9);
        (assets[0], assets[1], assets[2], assets[3], assets[4]) = (USDT, WOKB, XETH, XSOL, XBTC);
        (assets[5], assets[6], assets[7], assets[8]) = (USDG, USDC, USDT_OLD, WETH);
        IERC20(UNI).approve(FIREPIT, IFirepit(FIREPIT).threshold());
        IFirepit(FIREPIT).release(IFirepit(FIREPIT).nonce(), assets, address(seller));

        // 3. Turn everything into USD₮0. Order matters: xETH/xSOL/xBTC can route via USDG,
        //    so sell those first and USDG last.
        console.log("USDT0 released from jar:  %6e", IERC20(USDT).balanceOf(address(seller)));
        seller.sell(XETH, _routes3(_p(XETH_USDT0_500), _p2(XETH_USDG_500, USDG_USDT0_100), _p2(XETH_XSOL_500, XSOL_USDT0_500)), 20);
        console.log("  after selling xETH:     %6e", IERC20(USDT).balanceOf(address(seller)));
        seller.sell(XSOL, _routes3(_p(XSOL_USDT0_500), _p2(XSOL_USDG_500, USDG_USDT0_100), _p3(XETH_XSOL_500, XETH_USDG_500, USDG_USDT0_100)), 20);
        console.log("  after selling xSOL:     %6e", IERC20(USDT).balanceOf(address(seller)));
        seller.sell(XBTC, _routes3(_p(XBTC_USDT0_500), _p(XBTC_USDT0_100), _p3(XBTC_XETH_500, XETH_USDG_500, USDG_USDT0_100)), 20);
        console.log("  after selling xBTC:     %6e", IERC20(USDT).balanceOf(address(seller)));
        seller.sell(WOKB, _routes3(_p(OKB_USDT0_500), _p(OKB_USDT0_3000), _p(OKB_USDT0_100)), 20);
        console.log("  after selling OKB:      %6e", IERC20(USDT).balanceOf(address(seller)));
        seller.sell(USDG, _routes1(_p(USDG_USDT0_100)), 1);
        seller.sweep(USDT, user);

        vm.stopPrank();
        checkSolve();
    }

    function _p(address a) internal pure returns (address[] memory r) {
        r = new address[](1);
        r[0] = a;
    }

    function _p2(address a, address b) internal pure returns (address[] memory r) {
        r = new address[](2);
        (r[0], r[1]) = (a, b);
    }

    function _p3(address a, address b, address c) internal pure returns (address[] memory r) {
        r = new address[](3);
        (r[0], r[1], r[2]) = (a, b, c);
    }

    function _routes1(address[] memory a) internal pure returns (address[][] memory r) {
        r = new address[][](1);
        r[0] = a;
    }

    function _routes3(address[] memory a, address[] memory b, address[] memory c)
        internal
        pure
        returns (address[][] memory r)
    {
        r = new address[][](3);
        (r[0], r[1], r[2]) = (a, b, c);
    }

    function checkSolve() public view {
        require(IERC20(USDT).balanceOf(user) >= 45_000e6, "not enough USDT");
        console.log("Firepit solved. USDT: %6e", IERC20(USDT).balanceOf(user));
    }
}
