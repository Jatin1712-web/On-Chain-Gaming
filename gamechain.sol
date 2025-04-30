// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title CorePlay: Simple Dice Game
 * @dev This contract implements a basic dice game on Core Chain
 */
contract CorePlayDice is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Game constants
    uint8 public constant MIN_NUMBER = 1;
    uint8 public constant MAX_NUMBER = 6;
    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant MAX_BET = 10 ether;
    uint256 public constant HOUSE_EDGE_PERCENT = 2; // 2% house edge
    
    // Player stats tracking
    struct PlayerStats {
        uint256 gamesPlayed;
        uint256 gamesWon;
        uint256 totalWagered;
        uint256 totalWon;
        uint256 lastPlayedTimestamp;
    }
    
    // Achievement NFT tracking
    Counters.Counter private _tokenIdCounter;
    
    // Game events
    event GamePlayed(
        address indexed player,
        uint8 playerGuess,
        uint8 diceResult,
        uint256 betAmount,
        uint256 payout,
        bool isWin
    );
    
    event AchievementMinted(
        address indexed player,
        uint256 tokenId,
        string achievementType
    );
    
    // Mappings
    mapping(address => PlayerStats) public playerStats;
    mapping(uint256 => string) public tokenIdToAchievementType;
    
    constructor() ERC721("CorePlay Achievement", "CPA") Ownable(msg.sender) {}

    /**
     * @dev Main gameplay function where players bet on a dice roll
     * @param _guess The number player guesses (1-6)
     */
    function playDiceGame(uint8 _guess) external payable nonReentrant {
        // Input validation
        require(_guess >= MIN_NUMBER && _guess <= MAX_NUMBER, "Invalid guess: must be between 1 and 6");
        require(msg.value >= MIN_BET && msg.value <= MAX_BET, "Bet amount outside allowed range");
        
        // Generate pseudo-random dice roll (note: not truly random - would use VRF in production)
        uint8 diceResult = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, blockhash(block.number - 1)))) % MAX_NUMBER) + 1;
        
        // Calculate potential payout (5x bet minus house edge)
        uint256 houseEdge = (msg.value * HOUSE_EDGE_PERCENT) / 100;
        uint256 potentialPayout = (msg.value * 5) - houseEdge;
        
        // Update player stats
        playerStats[msg.sender].gamesPlayed += 1;
        playerStats[msg.sender].totalWagered += msg.value;
        playerStats[msg.sender].lastPlayedTimestamp = block.timestamp;
        
        bool isWin = (_guess == diceResult);
        
        // Handle win condition
        if (isWin) {
            playerStats[msg.sender].gamesWon += 1;
            playerStats[msg.sender].totalWon += potentialPayout;
            
            // Check if player achieved a milestone and mint NFT if needed
            checkAndMintAchievement(msg.sender);
            
            // Transfer winnings to player
            (bool sent, ) = payable(msg.sender).call{value: potentialPayout}("");
            require(sent, "Failed to send winnings");
        }
        
        // Emit game result event
        emit GamePlayed(
            msg.sender,
            _guess,
            diceResult,
            msg.value,
            isWin ? potentialPayout : 0,
            isWin
        );
    }
    
    /**
     * @dev Internal function to check if player qualifies for achievement NFT
     * @param _player Address of the player to check
     */
    function checkAndMintAchievement(address _player) internal {
        PlayerStats memory stats = playerStats[_player];
        
        // First win achievement
        if (stats.gamesWon == 1) {
            _mintAchievement(_player, "First Win");
        }
        // High roller achievement (bet more than 5 ETH total)
        else if (stats.totalWagered >= 5 ether && stats.gamesPlayed >= 5) {
            _mintAchievement(_player, "High Roller");
        }
        // Master player achievement (won more than 10 games)
        else if (stats.gamesWon == 10) {
            _mintAchievement(_player, "Master Player");
        }
    }
    
    /**
     * @dev Internal function to mint achievement NFT
     * @param _player Address to mint the achievement NFT to
     * @param _achievementType String describing achievement type
     */
    function _mintAchievement(address _player, string memory _achievementType) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(_player, tokenId);
        tokenIdToAchievementType[tokenId] = _achievementType;
        
        emit AchievementMinted(_player, tokenId, _achievementType);
    }
    
    /**
     * @dev Withdraw contract funds (for owner only)
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool sent, ) = payable(owner()).call{value: balance}("");
        require(sent, "Failed to withdraw funds");
    }
    
    // Fallback function
    receive() external payable {}
}
