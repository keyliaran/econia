/// Manages registration capabilities and operations.
///
/// # Functions
///
/// ## Public getters
///
/// * `get_custodian_id()`
/// * `get_underwriter_id()`
///
/// ## Public registration functions
///
/// * `register_custodian_capability()`
/// * `register_underwriter_capability()`
///
/// # Complete docgen index
///
/// The below index is automatically generated from source code:
module econia::registry {

    // Uses >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    use aptos_framework::account;
    use aptos_framework::coin::{Coin};
    use aptos_framework::event::EventHandle;
    use econia::incentives;
    use econia::tablist::{Self, Tablist};
    use std::option::Option;
    use std::string::String;

    // Uses <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Test-only uses >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test_only]
    use econia::assets::{Self, UC};

    // Test-only uses <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Structs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Custodian capability required to approve order placement, order
    /// cancellation, and coin withdrawals. Administered to third-party
    /// registrants who may store it as they wish.
    struct CustodianCapability has store {
        /// Serial ID, 1-indexed, generated upon registration as a
        /// custodian.
        custodian_id: u64
    }

    /// Emitted when a capability is registered.
    struct CapabilityRegistrationEvent has drop, store {
        /// Either `CUSTODIAN` or `UNDERWRITER`, the capability type
        /// just registered.
        capability_type: bool,
        /// ID of capability just registered.
        capability_id: u64
    }

    /// Type flag for generic asset. Must be passed as base asset type
    /// argument for generic market operations.
    struct GenericAsset has key {}

    /// Information about a market.
    struct MarketInfo has copy, drop, store {
        /// Base asset type name. When base asset is an
        /// `aptos_framework::coin::Coin`, corresponds to the phantom
        /// `CoinType` (`address:module::MyCoin` rather than
        /// `aptos_framework::coin::Coin<address:module::MyCoin>`), and
        /// `underwriter_id` is none. Otherwise can be any value, and
        /// `underwriter` is some.
        base_type: String,
        /// Quote asset coin type name. Corresponds to a phantom
        /// `CoinType` (`address:module::MyCoin` rather than
        /// `aptos_framework::coin::Coin<address:module::MyCoin>`).
        quote_type: String,
        /// Number of base units exchanged per lot (when base asset is
        /// a coin, corresponds to `aptos_framework::coin::Coin.value`).
        lot_size: u64,
        /// Number of quote coin units exchanged per tick (corresponds
        /// to `aptos_framework::coin::Coin.value`).
        tick_size: u64,
        /// ID of underwriter capability required to verify generic
        /// asset amounts. A market-wide ID that only applies to markets
        /// having a generic base asset. None when base and quote types
        /// are both coins.
        underwriter_id: Option<u64>
    }

    /// Emitted when a market is registered.
    struct MarketRegistrationEvent has drop, store {
        /// Market ID of the market just registered.
        market_id: u64,
        /// Base asset type name.
        base_type: String,
        /// Quote asset type name.
        quote_type: String,
        /// Number of base units exchanged per lot.
        lot_size: u64,
        /// Number of quote units exchanged per tick.
        tick_size: u64,
        /// ID of `UnderwriterCapability` required to verify generic
        /// asset amounts. None when base and quote types are both
        /// coins.
        underwriter_id: Option<u64>,
    }

    /// Emitted when a recognized market is added, removed, or updated.
    struct RecognizedMarketEvent has drop, store {
        /// The associated trading pair.
        trading_pair: TradingPair,
        /// The recognized market info for the given trading pair after
        /// an addition or update. None if a removal.
        recognized_market_info: Option<RecognizedMarketInfo>,
    }

    /// Recognized market info for a given trading pair.
    struct RecognizedMarketInfo has drop, store {
        /// Market ID of recognized market.
        market_id: u64,
        /// Number of base units exchanged per lot.
        lot_size: u64,
        /// Number of quote units exchanged per tick.
        tick_size: u64,
        /// ID of underwriter capability required to verify generic
        /// asset amounts. A market-wide ID that only applies to
        /// markets having a generic base asset. None when base and
        /// quote types are both coins.
        underwriter_id: Option<u64>,
    }

    /// Recognized markets for specific trading pairs.
    struct RecognizedMarkets has key {
        /// Map from trading pair info to market information for the
        /// recognized market, if any, for given trading pair.
        map: Tablist<TradingPair, RecognizedMarketInfo>,
        /// Event handle for recognized market events.
        recognized_market_events: EventHandle<RecognizedMarketEvent>
    }

    /// Global registration information.
    struct Registry has key {
        /// Map from market info to corresponding market ID, enabling
        /// duplicate checks and iterated indexing.
        markets: Tablist<MarketInfo, u64>,
        /// The number of registered custodians.
        n_custodians: u64,
        /// The number of registered underwriters.
        n_underwriters: u64,
        /// Event handle for market registration events.
        market_registration_events: EventHandle<MarketRegistrationEvent>,
        /// Event handle for capability registration events.
        capability_registration_events:
            EventHandle<CapabilityRegistrationEvent>
    }

    /// A combination of a base asset and a quote asset.
    struct TradingPair has copy, drop, store {
        /// Base type name.
        base_type: String,
        /// Quote type name.
        quote_type: String
    }

    /// Underwriter capability required to verify generic asset
    /// amounts. Administered to third-party registrants who may store
    /// it as they wish.
    struct UnderwriterCapability has store {
        /// Serial ID, 1-indexed, generated upon registration as an
        /// underwriter.
        underwriter_id: u64
    }

    // Structs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Constants >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Flag for custodian capability.
    const CUSTODIAN: bool = true;
    /// Flag for underwriter capability.
    const UNDERWRITER: bool = false;

    // Constants <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Public functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Return serial ID of given `CustodianCapability`.
    ///
    /// # Testing
    ///
    /// * `test_register_capabilities()`
    public fun get_custodian_id(
        custodian_capability_ref: &CustodianCapability
    ): u64 {
        custodian_capability_ref.custodian_id
    }

    /// Return serial ID of given `UnderwriterCapability`.
    ///
    /// # Testing
    ///
    /// * `test_register_capabilities()`
    public fun get_underwriter_id(
        underwriter_capability_ref: &UnderwriterCapability
    ): u64 {
        underwriter_capability_ref.underwriter_id
    }

    /// Return a unique `CustodianCapability`.
    ///
    /// Increment the number of registered custodians, then issue a
    /// capability with the corresponding serial ID. Requires utility
    /// coins to cover the custodian registration fee.
    ///
    /// # Testing
    ///
    /// * `test_register_capabilities()`
    public fun register_custodian_capability<UtilityCoinType>(
        utility_coins: Coin<UtilityCoinType>
    ): CustodianCapability
    acquires Registry {
        // Borrow mutable reference to registry.
        let registry_ref_mut = borrow_global_mut<Registry>(@econia);
        // Set custodian serial ID to the new number of custodians.
        let custodian_id = registry_ref_mut.n_custodians + 1;
        // Update the registry for the new count.
        registry_ref_mut.n_custodians = custodian_id;
        incentives:: // Deposit provided utility coins.
            deposit_custodian_registration_utility_coins(utility_coins);
        // Pack and return corresponding capability.
        CustodianCapability{custodian_id}
    }

    /// Return a unique `UnderwriterCapability`.
    ///
    /// Increment the number of registered underwriters, then issue a
    /// capability with the corresponding serial ID. Requires utility
    /// coins to cover the underwriter registration fee.
    ///
    /// # Testing
    ///
    /// * `test_register_capabilities()`
    public fun register_underwriter_capability<UtilityCoinType>(
        utility_coins: Coin<UtilityCoinType>
    ): UnderwriterCapability
    acquires Registry {
        // Borrow mutable reference to registry.
        let registry_ref_mut = borrow_global_mut<Registry>(@econia);
        // Set underwriter serial ID to the new number of underwriters.
        let underwriter_id = registry_ref_mut.n_underwriters + 1;
        // Update the registry for the new count.
        registry_ref_mut.n_underwriters = underwriter_id;
        incentives:: // Deposit provided utility coins.
            deposit_underwriter_registration_utility_coins(utility_coins);
        // Pack and return corresponding capability.
        UnderwriterCapability{underwriter_id}
    }

    // Public functions <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Private functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Initialize the Econia registry and recognized markets list upon
    /// module publication.
    fun init_module(
        econia: &signer
    ) {
        // Initialize registry.
        move_to(econia, Registry{
            markets: tablist::new(),
            n_custodians: 0,
            n_underwriters: 0,
            market_registration_events:
                account::new_event_handle<MarketRegistrationEvent>(econia),
            capability_registration_events:
                account::new_event_handle<CapabilityRegistrationEvent>(econia)
        });
        // Initialize recognized markets list.
        move_to(econia, RecognizedMarkets{
            map: tablist::new(),
            recognized_market_events:
                account::new_event_handle<RecognizedMarketEvent>(econia)
        });
    }

    // Private functions <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Test-only functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test_only]
    /// Drop the given `CustodianCapability`.
    public fun drop_custodian_capability_test(
        custodian_capability: CustodianCapability
    ) {
        // Unpack provided capability.
        let CustodianCapability{custodian_id: _} = custodian_capability;
    }

    #[test_only]
    /// Drop the given `UnderwriterCapability`.
    public fun drop_underwriter_capability_test(
        underwriter_capability: UnderwriterCapability
    ) {
        // Unpack provided capability.
        let UnderwriterCapability{underwriter_id: _} = underwriter_capability;
    }

    #[test_only]
    /// Initialize registry for testing.
    public fun init_test() {
        // Get signer for Econia account.
        let econia = account::create_signer_with_capability(
            &account::create_test_signer_cap(@econia));
        // Create Aptos-style account for Econia.
        account::create_account_for_test(@econia);
        init_module(&econia); // Init registry.
    }

    // Test-only functions <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test]
    /// Verify custodian then underwriter capability registration.
    fun test_register_capabilities()
    acquires Registry {
        init_test(); // Init registry and recognized markets list.
        incentives::init_test(); // Initialize incentives parameters.
        // Get custodian registration fee.
        let custodian_registration_fee =
            incentives::get_custodian_registration_fee();
        // Get custodian capability.
        let custodian_capability = register_custodian_capability(
            assets::mint_test<UC>(custodian_registration_fee));
        // Assert it has ID 1.
        assert!(get_custodian_id(&custodian_capability) == 1, 0);
        // Drop custodian capability.
        drop_custodian_capability_test(custodian_capability);
        // Get another custodian capability.
        custodian_capability = register_custodian_capability(
            assets::mint_test<UC>(custodian_registration_fee));
        // Assert it has ID 2.
        assert!(get_custodian_id(&custodian_capability) == 2, 0);
        // Drop custodian capability.
        drop_custodian_capability_test(custodian_capability);
        // Get another custodian capability.
        custodian_capability = register_custodian_capability(
            assets::mint_test<UC>(custodian_registration_fee));
        // Assert it has ID 3.
        assert!(get_custodian_id(&custodian_capability) == 3, 0);
        // Drop custodian capability.
        drop_custodian_capability_test(custodian_capability);
        // Get underwriter registration fee.
        let underwriter_registration_fee =
            incentives::get_underwriter_registration_fee();
        // Get underwriter capability.
        let underwriter_capability = register_underwriter_capability(
            assets::mint_test<UC>(underwriter_registration_fee));
        // Assert it has ID 1.
        assert!(get_underwriter_id(&underwriter_capability) == 1, 0);
        // Drop underwriter capability.
        drop_underwriter_capability_test(underwriter_capability);
        // Get another underwriter capability.
        underwriter_capability = register_underwriter_capability(
            assets::mint_test<UC>(underwriter_registration_fee));
        // Assert it has ID 2.
        assert!(get_underwriter_id(&underwriter_capability) == 2, 0);
        // Drop underwriter capability.
        drop_underwriter_capability_test(underwriter_capability);
        // Get another underwriter capability.
        underwriter_capability = register_underwriter_capability(
            assets::mint_test<UC>(underwriter_registration_fee));
        // Assert it has ID 3.
        assert!(get_underwriter_id(&underwriter_capability) == 3, 0);
        // Drop underwriter capability.
        drop_underwriter_capability_test(underwriter_capability);
    }

    // Tests <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

}