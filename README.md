APZ_CHAIN 
---

🔹 توضیح کلی

APZ-Chain یک زنجیره‌ی بلاک‌چینی مبتنی بر اتریوم مجازی (EVM) با توکن بومی APZ، استیکینگ، حاکمیت، API احراز هویت، ایندکسر و رابط کاربری وب است. هدف اصلی، آموزش آسان و ایجاد یک اکوسیستم غیرمتمرکز برای محتوای آموزشی و تعامل کاربران است.

---

📁 ساختار نهایی پروژه

```
apz-chain/
├── contracts/
│   ├── APZToken.sol
│   ├── Staking.sol
│   ├── Governance.sol
│   ├── hardhat.config.js
│   ├── package.json
│   ├── .echidna.yaml
│   └── test/
│       ├── token.test.js
│       ├── staking.test.js
│       ├── governance.test.js
│       ├── edgecases.test.js
│       ├── fuzz.test.js
│       ├── fuzz.seeded.test.js
│       └── FuzzStaking.t.sol
├── apps/
│   ├── api/
│   │   ├── package.json
│   │   ├── .env.example
│   │   └── src/
│   │       ├── server.js
│   │       └── routes/
│   │           └── tickets.js
│   ├── indexer/
│   │   ├── package.json
│   │   └── src/index.js
│   └── web/
│       ├── package.json
│       ├── README.md
│       └── pages/
│           ├── index.js
│           ├── api/tracks.js
│           ├── videos.js
│           ├── community.js
│           ├── support.js
│           └── register.js
├── docs/
│   ├── philosophy/easy-learning.md
│   └── education/
│       ├── sapnfc.md
│       ├── models.md
│       ├── school.md
│       ├── ticket.md
│       ├── reddit.md
│       ├── discord.md
│       ├── nef.md
│       └── en/
│           ├── sapnfc.md
│           ├── models.md
│           ├── school.md
│           ├── ticket.md
│           ├── reddit.md
│           ├── discord.md
│           └── nef.md
├── scripts/
│   ├── bootstrap-all.sh
│   ├── helm-bootstrap.sh
│   ├── generate-genesis.sh
│   └── bootstrap-validator.sh
├── infra/
│   ├── docker/
│   │   ├── node.Dockerfile
│   │   ├── indexer.Dockerfile
│   │   └── api.Dockerfile
│   ├── helm/
│   │   ├── node/
│   │   ├── indexer/
│   │   └── api/
│   └── devnet/docker-compose.yml
├── systemd/apz-node.service
├── openapi.yaml
├── genesis.json
├── README.md
├── .gitignore
└── .github/workflows/
    ├── contracts-ci.yml
    ├── fuzz-foundry-echidna.yml
    ├── ci-ghcr.yml
    └── ci-dockerhub.yml
```

---

🔹 فایل‌های اصلی (محتوای کامل)

1. contracts/APZToken.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract APZToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("APZ Token", "APZ") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
```

2. contracts/Staking.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is Ownable, ReentrancyGuard {
    IERC20 public stakingToken;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, uint256 _rewardRate) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _balances[msg.sender] += amount;
        _totalSupply += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            stakingToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (rewardRate * (block.timestamp - lastUpdateTime) * 1e18) / _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return ((_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }
}
```

3. contracts/Governance.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable {
    IERC20 public votingToken;
    uint256 public votingPeriod;
    uint256 public proposalCount;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) voted;
    }

    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed id, address proposer, string description);
    event Voted(uint256 indexed id, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    constructor(address _votingToken, uint256 _votingPeriod) Ownable(msg.sender) {
        votingToken = IERC20(_votingToken);
        votingPeriod = _votingPeriod;
    }

    function createProposal(string memory description) external {
        require(bytes(description).length > 0, "Description required");
        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.description = description;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + votingPeriod;
        emit ProposalCreated(proposalCount, msg.sender, description);
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.startTime && block.timestamp <= p.endTime, "Voting not active");
        require(!p.voted[msg.sender], "Already voted");
        uint256 weight = votingToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");
        p.voted[msg.sender] = true;
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.endTime, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.forVotes > p.againstVotes, "Proposal rejected");
        p.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (uint256, address, string memory, uint256, uint256, uint256, uint256, bool) {
        Proposal storage p = proposals[proposalId];
        return (p.id, p.proposer, p.description, p.forVotes, p.againstVotes, p.startTime, p.endTime, p.executed);
    }
}
```

4. contracts/hardhat.config.js

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("solidity-coverage");
require("hardhat-gas-reporter");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  },
  gasReporter: {
    enabled: true,
    currency: "USD"
  }
};
```

5. contracts/package.json

```json
{
  "name": "apz-contracts",
  "version": "1.0.0",
  "scripts": {
    "test": "npx hardhat test",
    "coverage": "npx hardhat coverage",
    "compile": "npx hardhat compile"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^5.0.0",
    "hardhat": "^2.22.0",
    "solidity-coverage": "^0.8.0",
    "hardhat-gas-reporter": "^1.0.9"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.2"
  }
}
```

6. contracts/.echidna.yaml

```yaml
testLimit: 100000
seqLen: 100
shrinkLimit: 5000
coverage: true
filterFunctions: ["setRewardRate"]
```

---

📁 تست‌ها (نمونه‌ها)

contracts/test/token.test.js

```javascript
const { expect } = require("chai");

describe("APZToken", function () {
  it("Should mint initial supply to owner", async function () {
    const Token = await ethers.getContractFactory("APZToken");
    const token = await Token.deploy(1000000);
    await token.waitForDeployment();
    const owner = await token.owner();
    const balance = await token.balanceOf(owner);
    expect(balance).to.equal(1000000 * 10 ** 18);
  });
});
```

contracts/test/fuzz.seeded.test.js (نمونه‌ی تست fuzz با استفاده از ethers و chai)

```javascript
const { expect } = require("chai");

describe("Fuzzing Staking with seeded random", function () {
  it("Should not allow stake 0", async function () {
    const Staking = await ethers.getContractFactory("Staking");
    const token = await (await ethers.getContractFactory("APZToken")).deploy(1000000);
    await token.waitForDeployment();
    const staking = await Staking.deploy(await token.getAddress(), 100);
    await staking.waitForDeployment();
    await expect(staking.stake(0)).to.be.revertedWith("Cannot stake 0");
  });
});
```

contracts/test/FuzzStaking.t.sol (تست Foundry)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../Staking.sol";
import "../APZToken.sol";

contract FuzzStakingTest is Test {
    Staking staking;
    APZToken token;
    address user = address(0x123);

    function setUp() public {
        token = new APZToken(1000000);
        staking = new Staking(address(token), 100);
        token.transfer(user, 1000 ether);
        vm.startPrank(user);
        token.approve(address(staking), 1000 ether);
        vm.stopPrank();
    }

    function testFuzz_StakeWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 ether);
        vm.startPrank(user);
        staking.stake(amount);
        uint256 balance = staking.balanceOf(user);
        assertEq(balance, amount);
        staking.withdraw(amount);
        assertEq(staking.balanceOf(user), 0);
        vm.stopPrank();
    }
}
```

---

📁 اپلیکیشن‌ها

apps/api/package.json

```json
{
  "name": "apz-api",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/server.js"
  },
  "dependencies": {
    "express": "^4.18.3",
    "jsonwebtoken": "^9.0.2",
    "dotenv": "^16.4.5",
    "cors": "^2.8.5"
  }
}
```

apps/api/.env.example

```
PORT=3000
JWT_SECRET=your-secret
```

apps/api/src/server.js

```javascript
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const ticketRoutes = require('./routes/tickets');

dotenv.config();
const app = express();
app.use(cors());
app.use(express.json());
app.use('/api/tickets', ticketRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API running on port ${PORT}`));
```

apps/api/src/routes/tickets.js

```javascript
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');

// ساخت تیکت (احراز هویت ساده)
router.post('/', (req, res) => {
  const { userId, track } = req.body;
  if (!userId || !track) return res.status(400).json({ error: 'Missing fields' });
  const token = jwt.sign({ userId, track }, process.env.JWT_SECRET, { expiresIn: '1h' });
  res.json({ ticket: token });
});

// تأیید تیکت
router.get('/verify/:token', (req, res) => {
  try {
    const decoded = jwt.verify(req.params.token, process.env.JWT_SECRET);
    res.json(decoded);
  } catch {
    res.status(401).json({ error: 'Invalid ticket' });
  }
});

module.exports = router;
```

---

apps/indexer/package.json

```json
{
  "name": "apz-indexer",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/index.js"
  },
  "dependencies": {
    "ethers": "^6.12.0",
    "dotenv": "^16.4.5"
  }
}
```

apps/indexer/src/index.js

```javascript
const { ethers } = require('ethers');
require('dotenv').config();

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL || 'http://localhost:8545');
const contractAddress = process.env.TOKEN_ADDRESS;
const abi = ['event Transfer(address indexed from, address indexed to, uint256 value)'];

const contract = new ethers.Contract(contractAddress, abi, provider);
contract.on('Transfer', (from, to, value) => {
  console.log(`Transfer: ${from} -> ${to} = ${value.toString()}`);
});
```

---

apps/web/package.json

```json
{
  "name": "apz-web",
  "version": "1.0.0",
  "scripts": {
    "dev": "next dev"
  },
  "dependencies": {
    "next": "^14.1.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  }
}
```

apps/web/pages/index.js

```javascript
export default function Home() {
  return <div><h1>Welcome to APZ-Chain</h1><p>Decentralized learning ecosystem</p></div>;
}
```

سایر صفحات مثل videos.js, community.js, support.js, register.js نیز به‌همین‌صورت ساده هستند (می‌توانید کپی کنید).

---

📁 مستندات (نمونه‌ها)

docs/philosophy/easy-learning.md

```markdown
# Easy Learning Philosophy
APZ-Chain believes in **learning by doing**. Our platform combines blockchain, education, and community to make complex topics accessible.
```

docs/education/sapnfc.md

```markdown
# SAP-NFC Model
An educational framework combining Self-Assessment, Practicals, NFTs, Feedback, and Community.
```

همه‌ی فایل‌های docs/education/*.md به‌همین‌شکل، توضیحات مختصر در مورد هر مفهوم دارند.

---

📁 اسکریپت‌ها

scripts/bootstrap-all.sh

```bash
#!/bin/bash
echo "Bootstrapping APZ-Chain..."
npm install --prefix contracts
npm install --prefix apps/api
npm install --prefix apps/indexer
npm install --prefix apps/web
echo "Done."
```

scripts/generate-genesis.sh

```bash
#!/bin/bash
cat > genesis.json <<EOF
{
  "config": {
    "chainId": 12345,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0
  },
  "alloc": {},
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x20000",
  "extraData": "",
  "gasLimit": "0x2fefd8",
  "nonce": "0x0000000000000042",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x00"
}
EOF
echo "genesis.json created."
```

---

📁 Infrastructure

infra/docker/node.Dockerfile

```dockerfile
FROM ethereum/client-go:v1.13.14
COPY genesis.json /genesis.json
CMD ["geth", "--datadir", "/data", "init", "/genesis.json"]
```

infra/docker/api.Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY apps/api/package*.json ./
RUN npm install
COPY apps/api/src ./src
CMD ["npm", "start"]
```

infra/devnet/docker-compose.yml

```yaml
version: '3'
services:
  node:
    build:
      context: ../..
      dockerfile: infra/docker/node.Dockerfile
    ports:
      - "8545:8545"
    command: ["geth", "--http", "--http.addr", "0.0.0.0", "--http.port", "8545", "--http.api", "eth,net,web3"]
  api:
    build:
      context: ../..
      dockerfile: infra/docker/api.Dockerfile
    ports:
      - "3000:3000"
    environment:
      - RPC_URL=http://node:8545
  indexer:
    build:
      context: ../..
      dockerfile: infra/docker/indexer.Dockerfile
    environment:
      - RPC_URL=http://node:8545
```

---

📁 Systemd و فایل‌های دیگر

systemd/apz-node.service

```ini
[Unit]
Description=APZ Geth Node
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/bin/geth --datadir /var/lib/apz-chain --http --http.addr 0.0.0.0 --http.port 8545
Restart=always

[Install]
WantedBy=multi-user.target
```

openapi.yaml (خلاصه)

```yaml
openapi: 3.0.0
info:
  title: APZ API
  version: 1.0.0
paths:
  /api/tickets:
    post:
      summary: Create a ticket
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                userId:
                  type: string
                track:
                  type: string
      responses:
        '200':
          description: Success
```

genesis.json (همان اسکریپت generate-genesis.sh تولید می‌کند)

README.md

```markdown
# APZ-Chain
Decentralized learning ecosystem with APZ token, staking, governance, and educational content.

## Quick Start
```bash
./scripts/bootstrap-all.sh
cd contracts && npx hardhat test
```

License

MIT

```

#### `.gitignore`
```

node_modules/
.env
coverage/
artifacts/
cache/
data/

```

---

### 📁 GitHub Actions

#### `.github/workflows/contracts-ci.yml`
```yaml
name: Contracts CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm install --prefix contracts
      - run: npx hardhat test --prefix contracts
```

.github/workflows/fuzz-foundry-echidna.yml

```yaml
name: Fuzzing with Foundry & Echidna
on: [push]
jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: cd contracts && forge test
      - uses: crytic/echidna-action@v3
        with:
          solc-version: 0.8.20
          contract: Staking
          config: contracts/.echidna.yaml
```

.github/workflows/ci-ghcr.yml (مثال ساخت و انتشار Docker image)

```yaml
name: Build and Push to GHCR
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          context: .
          file: infra/docker/api.Dockerfile
          push: true
          tags: ghcr.io/${{ github.repository }}/api:latest
```
