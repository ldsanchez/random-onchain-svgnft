// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase {
    address payable public owner;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public tokenCounter;

    // SVG parameters
    uint256 public size;
    string[] public colors;
    uint256 public price;

    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => uint256) public requestIdToTokenId;
    mapping(uint256 => uint256) public tokenIdToRandomNumber;

    event RequestRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId);
    event CreatedUnfinishedRandomSVG(
        uint256 indexed tokenId,
        uint256 randomNumber
    );
    event CreatedRandomSVG(uint256 indexed tokenId, string tokenURI);

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyHash,
        uint256 _fee
    )
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721("Random SVG NFT", "rsvgNFT")
    {
        fee = _fee;
        keyHash = _keyHash;
        tokenCounter = 0;
        price = 1000000000000000; // 0.001 ETH / MATIC / ETC
        size = 80;
        colors = ["#FFAD08", "#EDD75A", "#73B06F", "#0C8F8F", "#405059"];
    }

    function create() public payable returns (bytes32 requestId) {
        require(msg.value >= price, "Need to send more ETH");
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;
        uint256 tokenId = tokenCounter;
        requestIdToTokenId[requestId] = tokenId;
        tokenCounter = tokenCounter + 1;
        emit RequestRandomSVG(requestId, tokenId);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;
    }

    function withdraw() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdToTokenId[requestId];
        _safeMint(nftOwner, tokenId);
        tokenIdToRandomNumber[tokenId] = randomNumber;
        emit CreatedUnfinishedRandomSVG(tokenId, randomNumber);
    }

    function generateBackground(uint256 _randomNumber)
        public
        view
        returns (string memory backgroundSVG)
    {
        uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, 1)));
        string memory color = colors[newRNG % colors.length];
        backgroundSVG = "<g mask='url(#mask__beam)'><rect width='36' height='36' fill='";
        backgroundSVG = string.concat(backgroundSVG, color, "'></rect>");
    }

    function generateForeground(uint256 _randomNumber)
        public
        view
        returns (string memory foregroundSVG)
    {
        uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, 2)));
        string memory color = colors[newRNG % colors.length];
        foregroundSVG = "<rect x='0' y='0' width='36' height='36' transform='translate(9 -5) rotate(219 18 18) scale(1)' fill='";
        foregroundSVG = string.concat(
            foregroundSVG,
            color,
            "' rx='6'></rect><g transform='translate(4.5 -4) rotate(9 18 18)'><path d='M15 19c2 1 4 1 6 0' stroke='#FFFFFF' fill='none' stroke-linecap='round'></path><rect x='10' y='14' width='1.5' height='2' rx='1' stroke='none' fill='#FFFFFF'></rect><rect x='24' y='14' width='1.5' height='2' rx='1' stroke='none' fill='#FFFFFF'></rect></g></g>"
        );
    }

    function svgToImageURI(string memory _svg)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(_svg)))
        );
        string memory imageURI = string.concat(baseURL, svgBase64Encoded);
        return imageURI;
    }

    function formatTokenURI(string memory _imageURI)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:application/json;base64,";
        return
            string.concat(
                baseURL,
                Base64.encode(
                    bytes(
                        string.concat(
                            '{"name": "Random Boring Avatar SVG NFT",',
                            '"description": "A randomly generated on-chain SVG NFT based on Boring Avatars art",',
                            '"atributes": "",',
                            '"image": "',
                            _imageURI,
                            '"}'
                        )
                    )
                )
            );
    }

    function generateSVG(uint256 _randomNumber)
        public
        view
        returns (string memory finalSVG)
    {
        uint256 hasMask = _randomNumber % 2;
        finalSVG = string.concat(
            "<svg viewBox='0 0 36 36' xmlns='http://www.w3.org/2000/svg' width='",
            Strings.toString(size),
            "' height='",
            Strings.toString(size),
            "'>"
        );
        if (hasMask == 1) {
            finalSVG = string.concat(
                finalSVG,
                "<mask id='mask__beam' maskUnits='userSpaceOnUse' x='0' y='0' width='36' height='36'><rect width='36' height='36' rx='72' fill='#FFFFFF'></rect></mask>"
            );
        }
        string memory backgroundSVG = generateBackground(_randomNumber);
        finalSVG = string.concat(finalSVG, backgroundSVG);
        string memory foregroundSVG = generateForeground(_randomNumber);
        finalSVG = string.concat(finalSVG, foregroundSVG, "</svg>");
    }

    function finishMint(uint256 _tokenId) public {
        require(
            bytes(tokenURI(_tokenId)).length <= 0,
            "tokenURI is already all set!"
        );
        require(tokenCounter > _tokenId, "TokenId has not been minted yet!");
        require(
            tokenIdToRandomNumber[_tokenId] > 0,
            "Need to wait for Chainlink VRF"
        );
        // generate some random SVG code
        uint256 randomNumber = tokenIdToRandomNumber[_tokenId];
        string memory svg = generateSVG(randomNumber);
        // turn that into an image URI
        string memory imageURI = svgToImageURI(svg);
        // use that imageURI to format into a tokenURI
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(_tokenId, tokenURI);

        emit CreatedRandomSVG(_tokenId, svg);
    }
}
