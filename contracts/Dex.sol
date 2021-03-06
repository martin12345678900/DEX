// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Dex {
  using SafeMath for uint256;

  struct Token {
    bytes32 ticker;
    address tokenAddress;
  }

  struct Order {
    uint256 id;
    Side side;
    bytes32 ticker;
    address trader;
    uint256 amount;
    uint256 filled;
    uint256 price;
    uint256 date;
  }

  enum Side {
    BUY,
    SELL
  }

  mapping(bytes32 => Token) public tokens;
  mapping(address => mapping(bytes32 => uint256)) public traderBalances;
  mapping(bytes32 => mapping(uint256 => Order[])) public orderbook;
  bytes32[] public tokenList;
  address public admin;

  uint256 public orderId;
  uint256 public tradeId;

  bytes32 public constant DAI = bytes32("DAI");

  event NewTrade(
    uint256 tradeId,
    uint256 orderId,
    bytes32 indexed ticker,
    address indexed trader1,
    address indexed trader2,
    uint256 amount,
    uint256 price,
    uint256 date
  );

  constructor() {
    admin = msg.sender;
  }

  function addToken(bytes32 ticker, address tokenAddress) external onlyAdmin {
    tokens[ticker] = Token(ticker, tokenAddress);
    tokenList.push(ticker);
  }

  function deposit(bytes32 ticker, uint256 amount)
    external
    tokenExists(ticker)
  {
    IERC20(tokens[ticker].tokenAddress).transferFrom(
      msg.sender,
      address(this),
      amount
    );
    traderBalances[msg.sender][ticker] += traderBalances[msg.sender][ticker]
      .add(amount);
  }

  function withdraw(bytes32 ticker, uint256 amount)
    external
    tokenExists(ticker)
  {
    require(traderBalances[msg.sender][ticker] >= amount, "not enough balance");
    IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    traderBalances[msg.sender][ticker] -= traderBalances[msg.sender][ticker]
      .sub(amount);
  }

  function createLimitOrder(
    bytes32 ticker,
    uint256 amount,
    uint256 price,
    Side side
  ) external tokenExists(ticker) tokenIsNotDai(ticker) {
    if (side == Side.SELL) {
      require(
        traderBalances[msg.sender][ticker] >= amount,
        "not enough balance"
      );
    } else {
      require(
        traderBalances[msg.sender][DAI] >= amount.mul(price),
        "not enough DAI"
      );
    }
    Order[] storage orders = orderbook[ticker][uint256(side)];
    orders.push(
      Order(
        orderId,
        side,
        ticker,
        msg.sender,
        amount,
        0,
        price,
        block.timestamp
      )
    );

    uint256 i = orders.length - 1 > 0 ? orders.length - 1 : 0;
    while (i > 0) {
      if (side == Side.BUY && orders[i - 1].price > orders[i].price) {
        break;
      }
      if (side == Side.SELL && orders[i - 1].price < orders[i].price) {
        break;
      }
      Order memory order = orders[i - 1];
      orders[i - 1] = orders[i];
      orders[i] = order;
      i = i.sub(1);
    }
    orderId = orderId.add(1);
  }

  function createMarketOrder(
    bytes32 ticker,
    uint256 amount,
    Side side
  ) external tokenExists(ticker) tokenIsNotDai(ticker) {
    if (side == Side.SELL) {
      require(
        traderBalances[msg.sender][ticker] >= amount,
        "not enough balance"
      );
    }
    Order[] storage orders = orderbook[ticker][
      side == Side.SELL ? uint256(Side.BUY) : uint256(Side.SELL)
    ];
    uint256 i;
    uint256 remaining = amount; // ????????????????

    while (i < orders.length && remaining > 0) {
      uint256 available = orders[i].amount.sub(orders[i].filled);
      uint256 matched = (remaining > available) ? available : remaining;
      remaining -= remaining.sub(matched);
      orders[i].filled += orders[i].filled.add(matched);
      emit NewTrade(
        tradeId,
        orders[i].id,
        ticker,
        orders[i].trader,
        msg.sender,
        matched,
        orders[i].price,
        block.timestamp
      );
      if (side == Side.SELL) {
        traderBalances[msg.sender][ticker] -= traderBalances[msg.sender][ticker]
          .sub(matched); // get rid of tokens refered to the ticker
        traderBalances[msg.sender][DAI] += traderBalances[msg.sender][DAI].add(
          matched.mul(orders[i].price)
        ); // increase the dai tokens for user that sells
        traderBalances[orders[i].trader][ticker] += traderBalances[
          orders[i].trader
        ][ticker].add(matched);
        traderBalances[orders[i].trader][DAI] -= traderBalances[
          orders[i].trader
        ][DAI].sub(matched.mul(orders[i].price));
      } else {
        require(
          traderBalances[msg.sender][DAI] >= matched.mul(orders[i].price),
          "not enough dai"
        );
        traderBalances[msg.sender][ticker] += traderBalances[msg.sender][ticker]
          .add(matched);
        traderBalances[msg.sender][DAI] -= traderBalances[msg.sender][DAI].sub(
          matched.mul(orders[i].price)
        );
        traderBalances[orders[i].trader][ticker] -= traderBalances[
          orders[i].trader
        ][ticker].sub(matched);
        traderBalances[orders[i].trader][DAI] += traderBalances[
          orders[i].trader
        ][DAI].add(matched.mul(orders[i].price));
      }
      tradeId = tradeId.add(1);
      i = i.add(1);
    }

    i = 0;
    while (i < orders.length && orders[i].amount == orders[i].filled) {
      for (uint256 j = i; j < orders.length - 1; j++) {
        orders[j] = orders[j + 1];
      }
      orders.pop();
      i = i.add(1);
    }
  }

  function getOrders(bytes32 ticker, Side side)
    external
    view
    returns (Order[] memory)
  {
    return orderbook[ticker][uint256(side)];
  }

  function getTokens() external view returns (bytes32[] memory) {
    bytes32[] memory _tokens = new bytes32[](tokenList.length);
    for (uint256 i = 0; i < tokenList.length; i++) {
      _tokens[i] = tokenList[i];
    }
    return _tokens;
  }

  modifier onlyAdmin() {
    require(admin == msg.sender, "admin only");
    _;
  }

  modifier tokenExists(bytes32 ticker) {
    require(tokens[ticker].tokenAddress != address(0), "invalid token");
    _;
  }

  modifier tokenIsNotDai(bytes32 ticker) {
    require(ticker != DAI, "cannot trade DAI");
    _;
  }
}
