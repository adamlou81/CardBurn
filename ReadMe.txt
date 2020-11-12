    lotery()规则：
    1. 只有数量为2，3，4的卡片数可以烧掉并生成另外一张卡片
    2. 最高层的卡片不能被烧掉；
    3. 只有同一层的卡片才能被烧掉；
    4. 如果数量为2：50%生成高一级卡片一张，有elitePossibility%的几率升级为elite卡片；
    5. 如果数量为3：75%生成高一级卡片一张，(有elitePossibility*13)%的几率升级为elite卡片;
    6. 如果数量为4：100%生成高一级卡片一张，(有elitePossibility*16)%的几率升级为elite卡片;
    7. 如果烧掉的卡片中有elite卡片，则生成的卡片升级为elite的几率额外提升 extraElitePossibility*10





    ERC721 数据结构：
    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI;