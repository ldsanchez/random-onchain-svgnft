// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";
import "./SVG.sol";
import "./Utils.sol";

error Not__Owner();
error Not__EnoughETH();
error Token__AlreadySet();
error Token__NotMinted();
error Wainting__VRF();

contract RandomSVG is ERC721URIStorage, VRFConsumerBase {
    address payable public owner;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public tokenCounter;
    int256 public threshold;

    struct BoringAvatar {
        string hasMask;
        string maskColor;
        string faceColor;
    }
    BoringAvatar boringAvatar;

    // SVG parameters
    uint256 immutable size;
    string[] public colors;
    string[] public masks;
    bool public isHappy;
    string[] public happySmiles;
    string[] public sadSmiles;
    uint256 public price;

    AggregatorV3Interface internal immutable i_priceFeed;

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
        int256 _threshold,
        address _priceFeedAddress,
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyHash,
        uint256 _fee
    )
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721("Random SVG NFT", "rsvgNFT")
    {
        threshold = _threshold;
        i_priceFeed = AggregatorV3Interface(_priceFeedAddress);
        fee = _fee;
        keyHash = _keyHash;
        tokenCounter = 0;
        price = 1000000000000000; // 0.001 ETH / MATIC / ETC
        size = 100;
        masks = ["mask__beam", "none"];
        colors = ["#FFAD08", "#EDD75A", "#73B06F", "#0C8F8F", "#405059"];
        happySmiles = ["M15 21c2 1 4 1 6 0", "M15 19c2 1 4 1 6 0"];
        sadSmiles = ["M15 21c2 -1 4 -1 6 0", "M15 19c2 -2 4 -1 5 1"];
    }

    function create() public payable returns (bytes32 requestId) {
        if (msg.value < price) {
            revert Not__EnoughETH();
        }
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;
        uint256 tokenId = tokenCounter;
        requestIdToTokenId[requestId] = tokenId;
        tokenCounter = tokenCounter + 1;
        emit RequestRandomSVG(requestId, tokenId);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Not__Owner();
        }
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

    function expand(uint256 _randomNumber, uint256 n)
        public
        pure
        returns (uint256[] memory expandedValues)
    {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(
                keccak256(abi.encode(_randomNumber, i))
            );
        }
        return expandedValues;
    }

    function generateSVG(uint256 _randomNumber)
        public
        returns (string memory finalSVG)
    {
        (, int256 ethPrice, , , ) = i_priceFeed.latestRoundData();
        string memory smile;
        uint256[] memory randomValues = expand(_randomNumber, 3);

        if (ethPrice > threshold) {
            smile = happySmiles[randomValues[1] % happySmiles.length];
        } else {
            smile = sadSmiles[randomValues[1] % sadSmiles.length];
        }

        boringAvatar.hasMask = masks[randomValues[1] % 2];
        boringAvatar.maskColor = colors[randomValues[2] % colors.length];
        boringAvatar.faceColor = colors[randomValues[0] % colors.length];

        finalSVG = string.concat(
            "<svg viewBox='0 0 36 36' fill='none' role='img' xmlns='http://www.w3.org/2000/svg' width='",
            Strings.toString(size),
            "' height='",
            Strings.toString(size),
            "'>",
            svg.mask(
                string.concat(
                    svg.prop("id", boringAvatar.hasMask), // mask__beam
                    svg.prop("maskUnits", "userSpaceOnUse"),
                    svg.prop("x", "0"),
                    svg.prop("y", "0"),
                    svg.prop("width", "36"),
                    svg.prop("height", "36")
                ),
                svg.rect(
                    string.concat(
                        svg.prop("width", "36"),
                        svg.prop("height", "36"),
                        svg.prop("rx", "72"),
                        svg.prop("fill", "#FFFFFF")
                    ),
                    utils.NULL
                )
            ),
            svg.g(
                svg.prop("mask", "url(#mask__beam)"),
                string.concat(
                    svg.rect(
                        string.concat(
                            svg.prop("width", "36"),
                            svg.prop("height", "36"),
                            svg.prop("fill", boringAvatar.maskColor) // "#73b06f"
                        ),
                        utils.NULL
                    ),
                    svg.rect(
                        string.concat(
                            svg.prop("x", "0"),
                            svg.prop("y", "0"),
                            svg.prop("width", "36"),
                            svg.prop("height", "36"),
                            svg.prop(
                                "transform",
                                "translate(9 -5) rotate(219 18 18) scale(1)"
                            ),
                            svg.prop("fill", boringAvatar.faceColor), // "#405059"
                            svg.prop("rx", "6")
                        ),
                        utils.NULL
                    ),
                    svg.g(
                        svg.prop(
                            "transform",
                            "translate(4.5 -4) rotate(9 18 18)"
                        ),
                        string.concat(
                            svg.path(
                                string.concat(
                                    svg.prop("d", smile), // "M15 19c2 1 4 1 6 0"
                                    svg.prop("stroke", "#FFFFFF"),
                                    svg.prop("fill", "none"),
                                    svg.prop("stroke-linecap", "round")
                                ),
                                utils.NULL
                            ),
                            svg.rect(
                                string.concat(
                                    svg.prop("x", "10"),
                                    svg.prop("y", "14"),
                                    svg.prop("width", "1.5"),
                                    svg.prop("height", "2"),
                                    svg.prop("rx", "1"),
                                    svg.prop("stroke", "none"),
                                    svg.prop("fill", "#FFFFFF")
                                ),
                                utils.NULL
                            ),
                            svg.rect(
                                string.concat(
                                    svg.prop("x", "24"),
                                    svg.prop("y", "14"),
                                    svg.prop("width", "1.5"),
                                    svg.prop("height", "2"),
                                    svg.prop("rx", "1"),
                                    svg.prop("stroke", "none"),
                                    svg.prop("fill", "#FFFFFF")
                                ),
                                utils.NULL
                            )
                        )
                    )
                )
            ),
            "</svg>"
        );
    }

    function finishMint(uint256 _tokenId) public {
        if (bytes(tokenURI(_tokenId)).length > 0) {
            revert Token__AlreadySet();
        }
        if (tokenCounter < _tokenId) {
            revert Token__NotMinted();
        }
        if (tokenIdToRandomNumber[_tokenId] == 0) {
            revert Wainting__VRF();
        }
        // generate some random SVG code
        uint256 randomNumber = tokenIdToRandomNumber[_tokenId];
        string memory generatedSVG = generateSVG(randomNumber);
        // turn that into an image URI
        string memory imageURI = svgToImageURI(generatedSVG);
        // use that imageURI to format into a tokenURI
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(_tokenId, tokenURI);

        emit CreatedRandomSVG(_tokenId, generatedSVG);
    }
}
