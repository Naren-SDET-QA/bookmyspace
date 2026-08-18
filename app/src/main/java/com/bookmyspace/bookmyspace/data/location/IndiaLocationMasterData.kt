package com.bookmyspace.bookmyspace.data.location

import com.bookmyspace.bookmyspace.data.model.*
import kotlin.math.*

/**
 * Master Location Repository and Directory for India
 * Provides scalable Country → State → District → Mandal → City/Town/Village → Area relational hierarchy
 */
object IndiaLocationMasterData {

    val COUNTRY_INDIA = Country(
        id = "IN",
        code = "IND",
        name = "India",
        phoneCode = "+91",
        currency = "INR",
        isActive = true
    )

    // Supported States in India
    val STATES: List<State> = listOf(
        State(
            id = "IN-AP",
            countryId = "IN",
            code = "AP",
            name = "Andhra Pradesh",
            capitalCity = "Amaravati",
            latitude = 15.9129,
            longitude = 79.7400,
            displayOrder = 1
        ),
        State(
            id = "IN-TG",
            countryId = "IN",
            code = "TG",
            name = "Telangana",
            capitalCity = "Hyderabad",
            latitude = 17.8749,
            longitude = 78.1008,
            displayOrder = 2
        ),
        State(
            id = "IN-KA",
            countryId = "IN",
            code = "KA",
            name = "Karnataka",
            capitalCity = "Bengaluru",
            latitude = 15.3173,
            longitude = 75.7139,
            displayOrder = 3
        ),
        State(
            id = "IN-TN",
            countryId = "IN",
            code = "TN",
            name = "Tamil Nadu",
            capitalCity = "Chennai",
            latitude = 11.1271,
            longitude = 78.6569,
            displayOrder = 4
        ),
        State(
            id = "IN-MH",
            countryId = "IN",
            code = "MH",
            name = "Maharashtra",
            capitalCity = "Mumbai",
            latitude = 19.7515,
            longitude = 75.7139,
            displayOrder = 5
        )
    )

    // Districts Directory
    val DISTRICTS: List<District> = listOf(
        // Andhra Pradesh Districts
        District("DIST_AP_PRAKASAM", "IN-AP", "Prakasam", "PKM", "Ongole", 15.5057, 80.0499),
        District("DIST_AP_KRISHNA", "IN-AP", "NTR (Vijayawada)", "VJA", "Vijayawada", 16.5062, 80.6480),
        District("DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam", "VSKP", "Visakhapatnam", 17.6868, 83.2185),
        District("DIST_AP_GUNTUR", "IN-AP", "Guntur", "GNT", "Guntur", 16.3067, 80.4365),
        District("DIST_AP_TIRUPATI", "IN-AP", "Tirupati", "TPT", "Tirupati", 13.6288, 79.4192),
        District("DIST_AP_KURNOOL", "IN-AP", "Kurnool", "KNL", "Kurnool", 15.8281, 78.0373),
        District("DIST_AP_NELLORE", "IN-AP", "SPSR Nellore", "NLR", "Nellore", 14.4426, 79.9865),
        District("DIST_AP_KAKINADA", "IN-AP", "Kakinada", "KKD", "Kakinada", 16.9891, 82.2475),
        District("DIST_AP_KADAPA", "IN-AP", "YSR Kadapa", "KDP", "Kadapa", 14.4673, 78.8242),
        District("DIST_AP_ANANTAPUR", "IN-AP", "Anantapur", "ATP", "Anantapur", 14.6819, 77.6006),

        // Telangana Districts
        District("DIST_TG_HYDERABAD", "IN-TG", "Hyderabad", "HYD", "Hyderabad", 17.3850, 78.4867),
        District("DIST_TG_RANGAREDDY", "IN-TG", "Rangareddy", "RRD", "Shamshabad", 17.3300, 78.5000),
        District("DIST_TG_MEDCHAL", "IN-TG", "Medchal-Malkajgiri", "MDCL", "Malkajgiri", 17.5186, 78.5447),
        District("DIST_TG_WARANGAL", "IN-TG", "Warangal", "WGL", "Warangal", 17.9689, 79.5941),
        District("DIST_TG_KARIMNAGAR", "IN-TG", "Karimnagar", "KRM", "Karimnagar", 18.4386, 79.1288),
        District("DIST_TG_NIZAMABAD", "IN-TG", "Nizamabad", "NZB", "Nizamabad", 18.6725, 78.0941),
        District("DIST_TG_KHAMMAM", "IN-TG", "Khammam", "KMM", "Khammam", 17.2473, 80.1514),
        District("DIST_TG_NALGONDA", "IN-TG", "Nalgonda", "NLG", "Nalgonda", 17.0575, 79.2684),
        District("DIST_TG_MAHABUBNAGAR", "IN-TG", "Mahabubnagar", "MBNR", "Mahabubnagar", 16.7488, 77.9856),
        District("DIST_TG_SANGAREDDY", "IN-TG", "Sangareddy", "SRD", "Sangareddy", 17.6190, 78.0810),

        // Sample Other States
        District("DIST_KA_BLR_URBAN", "IN-KA", "Bengaluru Urban", "BLR", "Bengaluru", 12.9716, 77.5946),
        District("DIST_TN_CHENNAI", "IN-TN", "Chennai", "CHN", "Chennai", 13.0827, 80.2707),
        District("DIST_MH_MUMBAI", "IN-MH", "Mumbai City", "MUM", "Mumbai", 19.0760, 72.8777)
    )

    // Mandals Directory
    val MANDALS: List<Mandal> = listOf(
        // Prakasam District Mandals
        Mandal("MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ongole Mandal", "M_ONG", 15.5057, 80.0499),
        Mandal("MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Chirala Mandal", "M_CHR", 15.8230, 80.3520),
        Mandal("MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "Singarayakonda Mandal", "M_SGK", 15.2530, 80.0270),
        Mandal("MANDAL_AP_KANDUKUR", "DIST_AP_PRAKASAM", "IN-AP", "Kandukur Mandal", "M_KND", 15.2165, 79.9042),
        Mandal("MANDAL_AP_TANGUTUR", "DIST_AP_PRAKASAM", "IN-AP", "Tangutur Mandal", "M_TNG", 15.3900, 80.0400),
        Mandal("MANDAL_AP_ADDANKI", "DIST_AP_PRAKASAM", "IN-AP", "Addanki Mandal", "M_ADK", 15.8119, 79.9744),
        Mandal("MANDAL_AP_MARKAPUR", "DIST_AP_PRAKASAM", "IN-AP", "Markapur Mandal", "M_MKP", 15.7350, 79.2700),
        Mandal("MANDAL_AP_CHIMAKURTHY", "DIST_AP_PRAKASAM", "IN-AP", "Chimakurthy Mandal", "M_CMK", 15.5800, 79.8700),
        Mandal("MANDAL_AP_PODILI", "DIST_AP_PRAKASAM", "IN-AP", "Podili Mandal", "M_PDL", 15.6050, 79.6080),
        Mandal("MANDAL_AP_GIDDALUR", "DIST_AP_PRAKASAM", "IN-AP", "Giddalur Mandal", "M_GDL", 15.3780, 78.9270),

        // Krishna / NTR Mandals
        Mandal("MANDAL_AP_VJA_URBAN", "DIST_AP_KRISHNA", "IN-AP", "Vijayawada Urban", "M_VJAU", 16.5062, 80.6480),
        Mandal("MANDAL_AP_VJA_RURAL", "DIST_AP_KRISHNA", "IN-AP", "Vijayawada Rural", "M_VJAR", 16.5200, 80.6700),
        Mandal("MANDAL_AP_GANNAVARAM", "DIST_AP_KRISHNA", "IN-AP", "Gannavaram Mandal", "M_GNV", 16.5369, 80.7950),
        Mandal("MANDAL_AP_PENAMALURU", "DIST_AP_KRISHNA", "IN-AP", "Penamaluru Mandal", "M_PNM", 16.4670, 80.7000),

        // Visakhapatnam Mandals
        Mandal("MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam Urban", "M_VSKPU", 17.7210, 83.3150),
        Mandal("MANDAL_AP_GAJUWAKA", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Gajuwaka Mandal", "M_GJW", 17.6950, 83.2180),
        Mandal("MANDAL_AP_BHEEMLI", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Bheemunipatnam Mandal", "M_BHM", 17.8900, 83.4500),

        // Guntur Mandals
        Mandal("MANDAL_AP_GNT_URBAN", "DIST_AP_GUNTUR", "IN-AP", "Guntur Urban", "M_GNTU", 16.3067, 80.4365),
        Mandal("MANDAL_AP_MANGALAGIRI", "DIST_AP_GUNTUR", "IN-AP", "Mangalagiri Mandal", "M_MNG", 16.4300, 80.5500),

        // Tirupati Mandals
        Mandal("MANDAL_AP_TPT_URBAN", "DIST_AP_TIRUPATI", "IN-AP", "Tirupati Urban", "M_TPTU", 13.6288, 79.4192),
        Mandal("MANDAL_AP_RENIGUNTA", "DIST_AP_TIRUPATI", "IN-AP", "Renigunta Mandal", "M_RNG", 13.6350, 79.4600),

        // Hyderabad District Mandals
        Mandal("MANDAL_TG_SHAIKPET", "DIST_TG_HYDERABAD", "IN-TG", "Shaikpet (Jubilee Hills)", "M_SHK", 17.4125, 78.3980),
        Mandal("MANDAL_TG_KHAIRATABAD", "DIST_TG_HYDERABAD", "IN-TG", "Khairatabad (Banjara Hills)", "M_KHR", 17.4156, 78.4350),
        Mandal("MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad", "M_SEC", 17.4448, 78.4983),
        Mandal("MANDAL_TG_AMEERPET", "DIST_TG_HYDERABAD", "IN-TG", "Ameerpet", "M_AMP", 17.4375, 78.4482),
        Mandal("MANDAL_TG_MUSHEERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Musheerabad", "M_MSH", 17.4200, 78.4900),
        Mandal("MANDAL_TG_CHARMINAR", "DIST_TG_HYDERABAD", "IN-TG", "Charminar Old City", "M_CHR", 17.3616, 78.4747),

        // Rangareddy Mandals
        Mandal("MANDAL_TG_SERILINGAMPALLY", "DIST_TG_RANGAREDDY", "IN-TG", "Serilingampally (Gachibowli/HITEC)", "M_SLP", 17.4800, 78.3200),
        Mandal("MANDAL_TG_RAJENDRANAGAR", "DIST_TG_RANGAREDDY", "IN-TG", "Rajendranagar", "M_RJN", 17.3100, 78.4000),
        Mandal("MANDAL_TG_GANDIPET", "DIST_TG_RANGAREDDY", "IN-TG", "Gandipet", "M_GDP", 17.3912, 78.3180),
        Mandal("MANDAL_TG_SHAMSHABAD", "DIST_TG_RANGAREDDY", "IN-TG", "Shamshabad Airport", "M_SHM", 17.2500, 78.4300),

        // Medchal-Malkajgiri Mandals
        Mandal("MANDAL_TG_KUKATPALLY", "DIST_TG_MEDCHAL", "IN-TG", "Kukatpally", "M_KKT", 17.4938, 78.3989),
        Mandal("MANDAL_TG_MALKAJGIRI", "DIST_TG_MEDCHAL", "IN-TG", "Malkajgiri", "M_MLK", 17.4500, 78.5300),
        Mandal("MANDAL_TG_KOMPALLY", "DIST_TG_MEDCHAL", "IN-TG", "Kompally / Quthbullapur", "M_KMP", 17.5385, 78.4862),
        Mandal("MANDAL_TG_UPPAL", "DIST_TG_MEDCHAL", "IN-TG", "Uppal", "M_UPL", 17.4018, 78.5602),

        // Warangal Mandals
        Mandal("MANDAL_TG_HANAMKONDA", "DIST_TG_WARANGAL", "IN-TG", "Hanamkonda", "M_HNK", 17.9980, 79.5600),
        Mandal("MANDAL_TG_KAZIPET", "DIST_TG_WARANGAL", "IN-TG", "Kazipet", "M_KZP", 17.9780, 79.5120),

        // Sample Other States
        Mandal("MANDAL_KA_BLR_EAST", "DIST_KA_BLR_URBAN", "IN-KA", "Bengaluru East", "M_BLRE", 12.9716, 77.6412),
        Mandal("MANDAL_KA_BLR_SOUTH", "DIST_KA_BLR_URBAN", "IN-KA", "Bengaluru South", "M_BLRS", 12.9352, 77.6245)
    )

    // Cities / Towns Directory
    val CITIES: List<CityTown> = listOf(
        // Prakasam Cities
        CityTown("CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Ongole", SettlementType.CITY, "523001", 15.5057, 80.0499),
        CityTown("CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Chirala", SettlementType.TOWN, "523155", 15.8230, 80.3520),
        CityTown("CITY_AP_SINGARAYAKONDA", "MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "Singarayakonda", SettlementType.TOWN, "523101", 15.2530, 80.0270),
        CityTown("CITY_AP_KANDUKUR", "MANDAL_AP_KANDUKUR", "DIST_AP_PRAKASAM", "IN-AP", "Kandukur", SettlementType.TOWN, "523105", 15.2165, 79.9042),
        CityTown("CITY_AP_MARKAPUR", "MANDAL_AP_MARKAPUR", "DIST_AP_PRAKASAM", "IN-AP", "Markapur", SettlementType.TOWN, "523316", 15.7350, 79.2700),
        CityTown("CITY_AP_ADDANKI", "MANDAL_AP_ADDANKI", "DIST_AP_PRAKASAM", "IN-AP", "Addanki", SettlementType.TOWN, "523201", 15.8119, 79.9744),

        // Krishna Cities
        CityTown("CITY_AP_VIJAYAWADA", "MANDAL_AP_VJA_URBAN", "DIST_AP_KRISHNA", "IN-AP", "Vijayawada", SettlementType.METRO_CITY, "520001", 16.5062, 80.6480),
        CityTown("CITY_AP_GANNAVARAM", "MANDAL_AP_GANNAVARAM", "DIST_AP_KRISHNA", "IN-AP", "Gannavaram", SettlementType.TOWN, "521101", 16.5369, 80.7950),

        // Visakhapatnam Cities
        CityTown("CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Visakhapatnam", SettlementType.METRO_CITY, "530001", 17.6868, 83.2185),
        CityTown("CITY_AP_GAJUWAKA", "MANDAL_AP_GAJUWAKA", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Gajuwaka", SettlementType.CITY, "530026", 17.6950, 83.2180),

        // Guntur Cities
        CityTown("CITY_AP_GUNTUR", "MANDAL_AP_GNT_URBAN", "DIST_AP_GUNTUR", "IN-AP", "Guntur", SettlementType.CITY, "522001", 16.3067, 80.4365),
        CityTown("CITY_AP_MANGALAGIRI", "MANDAL_AP_MANGALAGIRI", "DIST_AP_GUNTUR", "IN-AP", "Mangalagiri", SettlementType.TOWN, "522503", 16.4300, 80.5500),

        // Tirupati Cities
        CityTown("CITY_AP_TIRUPATI", "MANDAL_AP_TPT_URBAN", "DIST_AP_TIRUPATI", "IN-AP", "Tirupati", SettlementType.CITY, "517501", 13.6288, 79.4192),
        CityTown("CITY_AP_RENIGUNTA", "MANDAL_AP_RENIGUNTA", "DIST_AP_TIRUPATI", "IN-AP", "Renigunta", SettlementType.TOWN, "517520", 13.6350, 79.4600),

        // Hyderabad & Greater Hyderabad Cities
        CityTown("CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_HYDERABAD", "IN-TG", "Hyderabad", SettlementType.METRO_CITY, "500001", 17.3850, 78.4867),
        CityTown("CITY_TG_SECUNDERABAD", "MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad", SettlementType.CITY, "500003", 17.4448, 78.4983),
        CityTown("CITY_TG_WARANGAL", "MANDAL_TG_HANAMKONDA", "DIST_TG_WARANGAL", "IN-TG", "Warangal", SettlementType.CITY, "506002", 17.9689, 79.5941),
        CityTown("CITY_TG_HANAMKONDA", "MANDAL_TG_HANAMKONDA", "DIST_TG_WARANGAL", "IN-TG", "Hanamkonda", SettlementType.CITY, "506001", 17.9980, 79.5600),
        CityTown("CITY_TG_KARIMNAGAR", "MANDAL_TG_KARIMNAGAR", "DIST_TG_KARIMNAGAR", "IN-TG", "Karimnagar", SettlementType.CITY, "505001", 18.4386, 79.1288),
        CityTown("CITY_TG_NIZAMABAD", "MANDAL_TG_NIZAMABAD", "DIST_TG_NIZAMABAD", "IN-TG", "Nizamabad", SettlementType.CITY, "503001", 18.6725, 78.0941),
        CityTown("CITY_TG_KHAMMAM", "MANDAL_TG_KHAMMAM", "DIST_TG_KHAMMAM", "IN-TG", "Khammam", SettlementType.CITY, "507001", 17.2473, 80.1514),

        // Other States Cities
        CityTown("CITY_KA_BENGALURU", "MANDAL_KA_BLR_EAST", "DIST_KA_BLR_URBAN", "IN-KA", "Bengaluru", SettlementType.METRO_CITY, "560001", 12.9716, 77.5946),
        CityTown("CITY_TN_CHENNAI", "DIST_TN_CHENNAI", "DIST_TN_CHENNAI", "IN-TN", "Chennai", SettlementType.METRO_CITY, "600001", 13.0827, 80.2707),
        CityTown("CITY_MH_MUMBAI", "DIST_MH_MUMBAI", "DIST_MH_MUMBAI", "IN-MH", "Mumbai", SettlementType.METRO_CITY, "400001", 19.0760, 72.8777)
    )

    // Areas / Localities Directory
    val AREAS: List<LocationArea> = listOf(
        // Ongole Areas
        LocationArea("AREA_AP_ONG_LAWYERPET", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Lawyerpet", "523001", "Near Clock Tower", 15.5030, 80.0460, isPopular = true),
        LocationArea("AREA_AP_ONG_KURNOOL_RD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Kurnool Road", "523002", "Near Flyover & Bus Station", 15.5090, 80.0380, isPopular = true),
        LocationArea("AREA_AP_ONG_SANTHAPETA", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Santhapeta", "523001", "Main Commercial Center", 15.5065, 80.0520, isPopular = true),
        LocationArea("AREA_AP_ONG_BHAGYANAGAR", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Bhagya Nagar", "523001", "Near Collector Office", 15.5120, 80.0430, isPopular = true),
        LocationArea("AREA_AP_ONG_TRUNK_RD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Trunk Road (GT Road)", "523001", "Trunk Road Shopping Stretch", 15.5045, 80.0490, isPopular = true),
        LocationArea("AREA_AP_ONG_MANGAMURU", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Mangamuru Road", "523002", "Residential Hub", 15.5180, 80.0320),
        LocationArea("AREA_AP_ONG_ANJAIAH_RD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Anjaiah Road", "523001", "Near Railway Station", 15.5010, 80.0480),
        LocationArea("AREA_AP_ONG_HOUSING_BOARD", "CITY_AP_ONGOLE", "MANDAL_AP_ONGOLE", "DIST_AP_PRAKASAM", "IN-AP", "Housing Board Colony", "523002", "APHB Colony", 15.5230, 80.0390),

        // Chirala Areas
        LocationArea("AREA_AP_CHR_KOTHAPETA", "CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Kothapeta", "523155", "Handloom & Textile Market", 15.8230, 80.3520, isPopular = true),
        LocationArea("AREA_AP_CHR_PERALA", "CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Perala", "523157", "Near Chirala Center", 15.8150, 80.3600),
        LocationArea("AREA_AP_CHR_BEACH_RD", "CITY_AP_CHIRALA", "MANDAL_AP_CHIRALA", "DIST_AP_PRAKASAM", "IN-AP", "Vodarevu Beach Road", "523155", "Resorts & Coastal Strip", 15.8020, 80.3800, isPopular = true),

        // Singarayakonda Areas
        LocationArea("AREA_AP_SGK_MAIN_RD", "CITY_AP_SINGARAYAKONDA", "MANDAL_AP_SINGARAYAKONDA", "DIST_AP_PRAKASAM", "IN-AP", "NH16 Bypass Road", "523101", "Near Highway Junction", 15.2530, 80.0270, isPopular = true),

        // Vijayawada Areas
        LocationArea("AREA_AP_VJA_BENZ_CIRCLE", "CITY_AP_VIJAYAWADA", "MANDAL_AP_VJA_URBAN", "DIST_AP_KRISHNA", "IN-AP", "Benz Circle", "520010", "Commercial & Convention Hub", 16.4975, 80.6557, isPopular = true),
        LocationArea("AREA_AP_VJA_MG_ROAD", "CITY_AP_VIJAYAWADA", "MANDAL_AP_VJA_URBAN", "DIST_AP_KRISHNA", "IN-AP", "MG Road (Bandar Road)", "520002", "Prime City Center", 16.5050, 80.6480, isPopular = true),
        LocationArea("AREA_AP_VJA_GOVERNORPET", "CITY_AP_VIJAYAWADA", "MANDAL_AP_VJA_URBAN", "DIST_AP_KRISHNA", "IN-AP", "Governorpet", "520002", "Near Bus Station", 16.5130, 80.6280),
        LocationArea("AREA_AP_VJA_AUTONAGAR", "CITY_AP_VIJAYAWADA", "MANDAL_AP_VJA_URBAN", "DIST_AP_KRISHNA", "IN-AP", "Autonagar", "520007", "Industrial & Banquet Belt", 16.4880, 80.6720, isPopular = true),
        LocationArea("AREA_AP_VJA_PORANKI", "CITY_AP_VIJAYAWADA", "MANDAL_AP_PENAMALURU", "DIST_AP_KRISHNA", "IN-AP", "Poranki / Penamaluru", "521137", "Luxury Lawns & Function Halls", 16.4750, 80.6900),

        // Visakhapatnam Areas
        LocationArea("AREA_AP_VSKP_SIRIPURAM", "CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Siripuram", "530003", "Near AU Campus", 17.7210, 83.3150, isPopular = true),
        LocationArea("AREA_AP_VSKP_MVP_COLONY", "CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "MVP Colony", "530017", "Largest Township", 17.7420, 83.3360, isPopular = true),
        LocationArea("AREA_AP_VSKP_DWARKA_NAGAR", "CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Dwarka Nagar", "530016", "Near RTC Complex", 17.7270, 83.3050, isPopular = true),
        LocationArea("AREA_AP_VSKP_BEACH_RD", "CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Beach Road (RK Beach)", "530002", "Seafront Events & Stays", 17.7120, 83.3240, isPopular = true),
        LocationArea("AREA_AP_VSKP_MADHURAWADA", "CITY_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Madhurawada IT SEZ", "530048", "Cricket Stadium Belt", 17.8160, 83.3600, isPopular = true),
        LocationArea("AREA_AP_VSKP_GAJUWAKA", "CITY_AP_GAJUWAKA", "MANDAL_AP_GAJUWAKA", "DIST_AP_VISAKHAPATNAM", "IN-AP", "Gajuwaka Industrial Hub", "530026", "Steel Plant Highway", 17.6950, 83.2180),

        // Guntur Areas
        LocationArea("AREA_AP_GNT_BRODIPET", "CITY_AP_GUNTUR", "MANDAL_AP_GNT_URBAN", "DIST_AP_GUNTUR", "IN-AP", "Brodipet", "522002", "Commercial Center", 16.3050, 80.4430, isPopular = true),
        LocationArea("AREA_AP_GNT_ARUNDELPET", "CITY_AP_GUNTUR", "MANDAL_AP_GNT_URBAN", "DIST_AP_GUNTUR", "IN-AP", "Arundelpet", "522002", "Function Halls Area", 16.3110, 80.4390, isPopular = true),
        LocationArea("AREA_AP_GNT_MANGALAGIRI", "CITY_AP_MANGALAGIRI", "MANDAL_AP_MANGALAGIRI", "DIST_AP_GUNTUR", "IN-AP", "Mangalagiri Highway / AIIMS", "522503", "Near Capital Expressway", 16.4300, 80.5500, isPopular = true),

        // Tirupati Areas
        LocationArea("AREA_AP_TPT_ALIPIRI", "CITY_AP_TIRUPATI", "MANDAL_AP_TPT_URBAN", "DIST_AP_TIRUPATI", "IN-AP", "Alipiri Bypass", "517507", "Foot of Tirumala Hills", 13.6520, 79.4080, isPopular = true),
        LocationArea("AREA_AP_TPT_AIRPORT_RD", "CITY_AP_RENIGUNTA", "MANDAL_AP_RENIGUNTA", "DIST_AP_TIRUPATI", "IN-AP", "Airport Road (Renigunta)", "517520", "Grand Kalyana Mandapams", 13.6350, 79.4600, isPopular = true),
        LocationArea("AREA_AP_TPT_KT_ROAD", "CITY_AP_TIRUPATI", "MANDAL_AP_TPT_URBAN", "DIST_AP_TIRUPATI", "IN-AP", "KT Road (Central)", "517501", "Near Railway Station", 13.6280, 79.4210),

        // Hyderabad & Cyberabad Areas
        LocationArea("AREA_TG_HYD_GACHIBOWLI", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_RANGAREDDY", "IN-TG", "Gachibowli", "500032", "Financial District & Stadium", 17.4401, 78.3489, isPopular = true),
        LocationArea("AREA_TG_HYD_HITEC_CITY", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_RANGAREDDY", "IN-TG", "HITEC City / Cyber Towers", "500081", "IT Corridor & Conventions", 17.4504, 78.3808, isPopular = true),
        LocationArea("AREA_TG_HYD_JUBILEE_HILLS", "CITY_TG_HYDERABAD", "MANDAL_TG_SHAIKPET", "DIST_TG_HYDERABAD", "IN-TG", "Jubilee Hills", "500033", "Road No 36 & 45 Luxury Venues", 17.4319, 78.4073, isPopular = true),
        LocationArea("AREA_TG_HYD_BANJARA_HILLS", "CITY_TG_HYDERABAD", "MANDAL_TG_KHAIRATABAD", "DIST_TG_HYDERABAD", "IN-TG", "Banjara Hills", "500034", "Road No 1 & 12 Luxury Hotels", 17.4156, 78.4350, isPopular = true),
        LocationArea("AREA_TG_HYD_MADHAPUR", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_RANGAREDDY", "IN-TG", "Madhapur", "500081", "Ayyappa Society & 100 Feet Rd", 17.4483, 78.3915, isPopular = true),
        LocationArea("AREA_TG_HYD_KONDAPUR", "CITY_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "DIST_TG_RANGAREDDY", "IN-TG", "Kondapur", "500084", "Botanical Garden Road", 17.4699, 78.3578, isPopular = true),
        LocationArea("AREA_TG_HYD_KUKATPALLY", "CITY_TG_HYDERABAD", "MANDAL_TG_KUKATPALLY", "DIST_TG_MEDCHAL", "IN-TG", "Kukatpally / KPHB", "500072", "KPHB Colony & Forum Mall", 17.4938, 78.3989, isPopular = true),
        LocationArea("AREA_TG_HYD_AMEERPET", "CITY_TG_HYDERABAD", "MANDAL_TG_AMEERPET", "DIST_TG_HYDERABAD", "IN-TG", "Ameerpet", "500016", "Education & Coaching Hub", 17.4375, 78.4482, isPopular = true),
        LocationArea("AREA_TG_HYD_BEGUMPET", "CITY_TG_HYDERABAD", "MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Begumpet", "500016", "Old Airport Road Banquets", 17.4448, 78.4682, isPopular = true),
        LocationArea("AREA_TG_HYD_SECUNDERABAD", "CITY_TG_SECUNDERABAD", "MANDAL_TG_SECUNDERABAD", "DIST_TG_HYDERABAD", "IN-TG", "Secunderabad Clock Tower", "500003", "Paradise & Station Belt", 17.4448, 78.4983, isPopular = true),
        LocationArea("AREA_TG_HYD_KOMPALLY", "CITY_TG_HYDERABAD", "MANDAL_TG_KOMPALLY", "DIST_TG_MEDCHAL", "IN-TG", "Kompally Highway", "500014", "Grand Resort & Marriage Palaces", 17.5385, 78.4862, isPopular = true),
        LocationArea("AREA_TG_HYD_GANDIPET", "CITY_TG_HYDERABAD", "MANDAL_TG_GANDIPET", "DIST_TG_RANGAREDDY", "IN-TG", "Gandipet Lake Road", "500075", "Lawn Resorts & Farmhouses", 17.3912, 78.3180, isPopular = true),
        LocationArea("AREA_TG_HYD_CHARMINAR", "CITY_TG_HYDERABAD", "MANDAL_TG_CHARMINAR", "DIST_TG_HYDERABAD", "IN-TG", "Charminar / Nayapul", "500002", "Historic Old City", 17.3616, 78.4747),

        // Warangal Areas
        LocationArea("AREA_TG_WGL_HANAMKONDA", "CITY_TG_WARANGAL", "MANDAL_TG_HANAMKONDA", "DIST_TG_WARANGAL", "IN-TG", "Hanamkonda Subedari", "506001", "NIT Warangal Belt", 17.9980, 79.5600, isPopular = true),
        LocationArea("AREA_TG_WGL_KAZIPET", "CITY_TG_WARANGAL", "MANDAL_TG_KAZIPET", "DIST_TG_WARANGAL", "IN-TG", "Kazipet Junction", "506003", "Railway Station Road", 17.9780, 79.5120),

        // Bengaluru Areas
        LocationArea("AREA_KA_BLR_KORAMANGALA", "CITY_KA_BENGALURU", "MANDAL_KA_BLR_SOUTH", "DIST_KA_BLR_URBAN", "IN-KA", "Koramangala", "560034", "Startup & Lounge Hub", 12.9352, 77.6245, isPopular = true),
        LocationArea("AREA_KA_BLR_INDIRANAGAR", "CITY_KA_BENGALURU", "MANDAL_KA_BLR_EAST", "DIST_KA_BLR_URBAN", "IN-KA", "Indiranagar", "560038", "100ft Road", 12.9719, 77.6412, isPopular = true),
        LocationArea("AREA_KA_BLR_WHITEFIELD", "CITY_KA_BENGALURU", "MANDAL_KA_BLR_EAST", "DIST_KA_BLR_URBAN", "IN-KA", "Whitefield", "560066", "ITPL Main Road", 12.9698, 77.7499, isPopular = true)
    )

    // Popular Quick Picks for Location Bar
    val POPULAR_LOCATION_PRESETS: List<LocationHierarchy> = listOf(
        // Telangana Top Picks
        buildHierarchy("IN-TG", "DIST_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "CITY_TG_HYDERABAD", "AREA_TG_HYD_GACHIBOWLI"),
        buildHierarchy("IN-TG", "DIST_TG_HYDERABAD", "MANDAL_TG_SHAIKPET", "CITY_TG_HYDERABAD", "AREA_TG_HYD_JUBILEE_HILLS"),
        buildHierarchy("IN-TG", "DIST_TG_HYDERABAD", "MANDAL_TG_KHAIRATABAD", "CITY_TG_HYDERABAD", "AREA_TG_HYD_BANJARA_HILLS"),
        buildHierarchy("IN-TG", "DIST_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "CITY_TG_HYDERABAD", "AREA_TG_HYD_HITEC_CITY"),
        buildHierarchy("IN-TG", "DIST_TG_HYDERABAD", "MANDAL_TG_SERILINGAMPALLY", "CITY_TG_HYDERABAD", "AREA_TG_HYD_MADHAPUR"),
        buildHierarchy("IN-TG", "DIST_TG_WARANGAL", "MANDAL_TG_HANAMKONDA", "CITY_TG_WARANGAL", "AREA_TG_WGL_HANAMKONDA"),

        // Andhra Pradesh Top Picks
        buildHierarchy("IN-AP", "DIST_AP_PRAKASAM", "MANDAL_AP_ONGOLE", "CITY_AP_ONGOLE", "AREA_AP_ONG_LAWYERPET"),
        buildHierarchy("IN-AP", "DIST_AP_PRAKASAM", "MANDAL_AP_ONGOLE", "CITY_AP_ONGOLE", "AREA_AP_ONG_KURNOOL_RD"),
        buildHierarchy("IN-AP", "DIST_AP_PRAKASAM", "MANDAL_AP_CHIRALA", "CITY_AP_CHIRALA", "AREA_AP_CHR_KOTHAPETA"),
        buildHierarchy("IN-AP", "DIST_AP_KRISHNA", "MANDAL_AP_VJA_URBAN", "CITY_AP_VIJAYAWADA", "AREA_AP_VJA_BENZ_CIRCLE"),
        buildHierarchy("IN-AP", "DIST_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "CITY_AP_VISAKHAPATNAM", "AREA_AP_VSKP_SIRIPURAM"),
        buildHierarchy("IN-AP", "DIST_AP_VISAKHAPATNAM", "MANDAL_AP_VSKP_URBAN", "CITY_AP_VISAKHAPATNAM", "AREA_AP_VSKP_MVP_COLONY"),
        buildHierarchy("IN-AP", "DIST_AP_GUNTUR", "MANDAL_AP_GNT_URBAN", "CITY_AP_GUNTUR", "AREA_AP_GNT_BRODIPET"),
        buildHierarchy("IN-AP", "DIST_AP_TIRUPATI", "MANDAL_AP_TPT_URBAN", "CITY_AP_TIRUPATI", "AREA_AP_TPT_ALIPIRI"),

        // Other Major Metros
        buildHierarchy("IN-KA", "DIST_KA_BLR_URBAN", "MANDAL_KA_BLR_SOUTH", "CITY_KA_BENGALURU", "AREA_KA_BLR_KORAMANGALA")
    )

    // Default Default Location
    val DEFAULT_LOCATION: LocationHierarchy = POPULAR_LOCATION_PRESETS[0]

    // Navigation and Query Resolvers
    fun getDistrictsForState(stateId: String): List<District> =
        DISTRICTS.filter { it.stateId.equals(stateId, ignoreCase = true) }

    fun getMandalsForDistrict(districtId: String): List<Mandal> =
        MANDALS.filter { it.districtId.equals(districtId, ignoreCase = true) }

    fun getCitiesForMandal(mandalId: String): List<CityTown> =
        CITIES.filter { it.mandalId.equals(mandalId, ignoreCase = true) }

    fun getCitiesForDistrict(districtId: String): List<CityTown> =
        CITIES.filter { it.districtId.equals(districtId, ignoreCase = true) }

    fun getAreasForCity(cityTownId: String): List<LocationArea> =
        AREAS.filter { it.cityTownId.equals(cityTownId, ignoreCase = true) }

    fun getAreasForMandal(mandalId: String): List<LocationArea> =
        AREAS.filter { it.mandalId.equals(mandalId, ignoreCase = true) }

    /**
     * Builds a structured LocationHierarchy from individual relational IDs
     */
    fun buildHierarchy(
        stateId: String,
        districtId: String,
        mandalId: String? = null,
        cityTownId: String? = null,
        areaId: String? = null
    ): LocationHierarchy {
        val state = STATES.firstOrNull { it.id.equals(stateId, ignoreCase = true) } ?: STATES[1] // Default Telangana
        val district = DISTRICTS.firstOrNull { it.id.equals(districtId, ignoreCase = true) }
            ?: DISTRICTS.firstOrNull { it.stateId == state.id } ?: DISTRICTS[10]
        val mandal = MANDALS.firstOrNull { it.id.equals(mandalId, ignoreCase = true) }
            ?: MANDALS.firstOrNull { it.districtId == district.id }
        val city = CITIES.firstOrNull { it.id.equals(cityTownId, ignoreCase = true) }
            ?: CITIES.firstOrNull { it.mandalId == mandal?.id || it.districtId == district.id }
        val area = AREAS.firstOrNull { it.id.equals(areaId, ignoreCase = true) }
            ?: AREAS.firstOrNull { it.cityTownId == city?.id }

        val lat = area?.latitude ?: city?.latitude ?: mandal?.latitude ?: district.latitude
        val lng = area?.longitude ?: city?.longitude ?: mandal?.longitude ?: district.longitude
        val postal = area?.postalCode?.ifBlank { city?.postalCode } ?: city?.postalCode ?: ""

        return LocationHierarchy(
            countryId = "IN",
            stateId = state.id,
            districtId = district.id,
            mandalId = mandal?.id ?: "",
            cityTownId = city?.id ?: "",
            areaId = area?.id,
            countryName = "India",
            stateName = state.name,
            districtName = district.name,
            mandalName = mandal?.name ?: "",
            cityName = city?.name ?: district.headquarters,
            areaName = area?.name ?: "",
            postalCode = postal,
            latitude = lat,
            longitude = lng
        )
    }

    /**
     * Calculates great-circle distance between two GPS coordinates using Haversine formula
     */
    fun calculateDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371.0 // Earth's radius in kilometers
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2.0) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2).pow(2.0)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }

    /**
     * Finds nearest supported LocationHierarchy matching given GPS coordinates
     */
    fun findNearestLocation(lat: Double, lng: Double): LocationHierarchy {
        // Find closest Area
        val closestArea = AREAS.minByOrNull { calculateDistanceKm(lat, lng, it.latitude, it.longitude) }
        if (closestArea != null) {
            val dist = calculateDistanceKm(lat, lng, closestArea.latitude, closestArea.longitude)
            if (dist < 40.0) {
                return buildHierarchy(
                    stateId = closestArea.stateId,
                    districtId = closestArea.districtId,
                    mandalId = closestArea.mandalId,
                    cityTownId = closestArea.cityTownId,
                    areaId = closestArea.id
                )
            }
        }

        // Otherwise find closest City
        val closestCity = CITIES.minByOrNull { calculateDistanceKm(lat, lng, it.latitude, it.longitude) }
        if (closestCity != null) {
            val dist = calculateDistanceKm(lat, lng, closestCity.latitude, closestCity.longitude)
            if (dist < 80.0) {
                return buildHierarchy(
                    stateId = closestCity.stateId,
                    districtId = closestCity.districtId,
                    mandalId = closestCity.mandalId,
                    cityTownId = closestCity.id
                )
            }
        }

        // Otherwise closest District
        val closestDistrict = DISTRICTS.minByOrNull { calculateDistanceKm(lat, lng, it.latitude, it.longitude) }
        if (closestDistrict != null) {
            return buildHierarchy(
                stateId = closestDistrict.stateId,
                districtId = closestDistrict.id
            )
        }

        return DEFAULT_LOCATION
    }

    /**
     * Search across states, districts, mandals, cities and areas
     */
    fun searchLocations(query: String): List<LocationHierarchy> {
        val q = query.trim().lowercase()
        if (q.isBlank()) return POPULAR_LOCATION_PRESETS

        val results = mutableListOf<LocationHierarchy>()

        // 1. Search Areas
        AREAS.filter { it.name.lowercase().contains(q) || it.postalCode.contains(q) || it.landmark.lowercase().contains(q) }
            .take(10)
            .forEach { area ->
                results.add(buildHierarchy(area.stateId, area.districtId, area.mandalId, area.cityTownId, area.id))
            }

        // 2. Search Cities / Towns
        CITIES.filter { it.name.lowercase().contains(q) || it.postalCode.contains(q) }
            .take(8)
            .forEach { city ->
                results.add(buildHierarchy(city.stateId, city.districtId, city.mandalId, city.id))
            }

        // 3. Search Mandals
        MANDALS.filter { it.name.lowercase().contains(q) }
            .take(6)
            .forEach { mandal ->
                results.add(buildHierarchy(mandal.stateId, mandal.districtId, mandal.id))
            }

        // 4. Search Districts
        DISTRICTS.filter { it.name.lowercase().contains(q) || it.headquarters.lowercase().contains(q) }
            .take(5)
            .forEach { district ->
                results.add(buildHierarchy(district.stateId, district.id))
            }

        // 5. Search States
        STATES.filter { it.name.lowercase().contains(q) }
            .take(3)
            .forEach { state ->
                val dist = DISTRICTS.firstOrNull { it.stateId == state.id }
                if (dist != null) {
                    results.add(buildHierarchy(state.id, dist.id))
                }
            }

        return results.distinctBy { "${it.stateId}_${it.districtId}_${it.cityTownId}_${it.areaId}" }
    }
}
