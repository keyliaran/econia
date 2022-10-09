/// AVL queue: a hybrid between an AVL tree and a queue.
///
/// # References
///
/// * [Adelson-Velski and Landis 1962] (original paper)
/// * [Galles 2011] (interactive visualizer)
/// * [Wikipedia 2022]
///
/// [Adelson-Velski and Landis 1962]:
///     https://zhjwpku.com/assets/pdf/AED2-10-avl-paper.pdf
/// [Galles 2011]:
///     https://www.cs.usfca.edu/~galles/visualization/AVLtree.html
/// [Wikipedia 2022]:
///     https://en.wikipedia.org/wiki/AVL_tree
///
/// # Node IDs
///
/// Tree nodes and list nodes are each assigned a 1-indexed 14-bit
/// serial ID known as a node ID. Node ID 0 is reserved for null, such
/// that the maximum number of allocated nodes for each node type is
/// thus $2^{14} - 1$.
///
/// # Access keys
///
/// | Bit(s) | Data                                         |
/// |--------|----------------------------------------------|
/// | 47-60  | Tree node ID                                 |
/// | 33-46  | List node ID                                 |
/// | 32     | If set, ascending AVL queue, else descending |
/// | 0-31   | Insertion key                                |
///
/// # Complete docgen index
///
/// The below index is automatically generated from source code:
module econia::avl_queue {

    // Uses >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    use aptos_std::table::{Self, Table};
    use aptos_std::table_with_length::{Self, TableWithLength};
    use std::option::{Self, Option};

    // Uses <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Test-only uses >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test_only]
    use std::vector;

    // Test-only uses <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Structs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// A hybrid between an AVL tree and a queue. See above.
    ///
    /// Most non-table fields stored compactly in `bits` as follows:
    ///
    /// | Bit(s)  | Data                                               |
    /// |---------|----------------------------------------------------|
    /// | 126     | If set, ascending AVL queue, else descending       |
    /// | 112-125 | Tree node ID at top of inactive stack              |
    /// | 98-111  | List node ID at top of inactive stack              |
    /// | 84-97   | AVL queue head list node ID                        |
    /// | 52-83   | AVL queue head insertion key (if node ID not null) |
    /// | 38-51   | AVL queue tail list node ID                        |
    /// | 6-37    | AVL queue tail insertion key (if node ID not null) |
    /// | 0-5     | Bits 8-13 of tree root node ID                     |
    ///
    /// Bits 0-7 of the tree root node ID are stored in `root_lsbs`.
    struct AVLqueue<V> has store {
        bits: u128,
        root_lsbs: u8,
        /// Map from tree node ID to tree node.
        tree_nodes: TableWithLength<u64, TreeNode>,
        /// Map from list node ID to list node.
        list_nodes: TableWithLength<u64, ListNode>,
        /// Map from list node ID to optional insertion value.
        values: Table<u64, Option<V>>
    }

    /// A tree node in an AVL queue.
    ///
    /// All fields stored compactly in `bits` as follows:
    ///
    /// | Bit(s) | Data                                 |
    /// |--------|--------------------------------------|
    /// | 86-117 | Insertion key                        |
    /// | 84-85  | Balance factor (see below)           |
    /// | 70-83  | Parent node ID                       |
    /// | 56-69  | Left child node ID                   |
    /// | 42-55  | Right child node ID                  |
    /// | 28-41  | List head node ID                    |
    /// | 14-27  | List tail node ID                    |
    /// | 0-13   | Next inactive node ID, when in stack |
    ///
    /// Balance factor bits:
    ///
    /// | Bit(s) | Balance factor             |
    /// |--------|----------------------------|
    /// | `0b10` | -1  (left subtree taller)  |
    /// | `0b00` | 0                          |
    /// | `0b01` | +1  (right subtree taller) |
    ///
    /// All fields except next inactive node ID are ignored when the
    /// node is in the inactive nodes stack.
    struct TreeNode has store {
        bits: u128
    }

    /// A list node in an AVL queue.
    ///
    /// For compact storage, last and next values are split into two
    /// `u8` fields each: one for most-significant bits (`last_msbs`,
    /// `next_msbs`), and one for least-significant bits (`last_lsbs`,
    /// `next_lsbs`).
    ///
    /// When set at bit 14, the 16-bit concatenated result of `_msbs`
    /// and `_lsbs` fields, in either case, refers to a tree node ID: If
    /// `last_msbs` and `last_lsbs` indicate a tree node ID, then the
    /// list node is the head of the list at the given tree node. If
    /// `next_msbs` and `next_lsbs` indicate a tree node ID, then the
    /// list node is the tail of the list at the given tree node.
    ///
    /// If not set at bit 14, the corresponding node ID is either the
    /// last or the next list node in the doubly linked list.
    ///
    /// If list node is in the inactive list node stack, next node ID
    /// indicates next inactive node in the stack.
    struct ListNode has store {
        last_msbs: u8,
        last_lsbs: u8,
        next_msbs: u8,
        next_lsbs: u8
    }

    // Structs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Error codes >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Number of allocated nodes is too high.
    const E_TOO_MANY_NODES: u64 = 0;

    // Error codes <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Constants >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Ascending AVL queue flag.
    const ASCENDING: bool = true;
    /// Bitmask set at bit 126, the result of `AVLqueue.bits` bitwise
    /// `AND` `AVL_QUEUE_BITS_SORT_ORDER` for an ascending AVL queue.
    /// Generated in Python via `hex(int('1' + '0' * 126, 2))`.
    const AVLQ_BITS_ASCENDING: u128 = 0x40000000000000000000000000000000;
    /// The result of `AVLqueue.bits` bitwise `AND`
    /// `AVL_QUEUE_BITS_SORT_ORDER` for a descending AVL queue.
    const AVLQ_BITS_DESCENDING: u128 = 0;
    /// Number of bits the inactive list node stack top node ID is
    /// shifted in `AVLqueue.bits`.
    const AVLQ_BITS_LIST_TOP_SHIFT: u8 = 98;
    /// Bitmask set at bit 126, the sort order bit flag in
    /// `AVLqueue.bits`. Generated in Python via
    /// `hex(int('1' + '0' * 126, 2))`.
    const AVLQ_BITS_SORT_ORDER: u128 = 0x40000000000000000000000000000000;
    /// Number of bits the inactive tree node stack top node ID is
    /// shifted in `AVLqueue.bits`.
    const AVLQ_BITS_TREE_TOP_SHIFT: u8 = 112;
    /// Number of bits in a byte.
    const BITS_PER_BYTE: u8 = 8;
    /// Descending AVL queue flag.
    const DESCENDING: bool = false;
    /// `u64` bitmask with all bits set, generated in Python via
    /// `hex(int('1' * 64, 2))`.
    const HI_64: u64 = 0xffffffffffffffff;
    /// `u128` bitmask with all bits set, generated in Python via
    /// `hex(int('1' * 128, 2))`.
    const HI_128: u128 = 0xffffffffffffffffffffffffffffffff;
    /// Set at bits 0-7, yielding most significant byte after bitwise
    /// `AND`. Generated in Python via `hex(int('1' * 8, 2))`.
    const LEAST_SIGNIFICANT_BYTE: u64 = 0xff;
    /// Flag for null node ID.
    const NIL: u64 = 0;
    /// Set at bits 0-13, for `AND` masking off all bits other than node
    /// ID contained in least-significant bits. Generated in Python via
    /// `hex(int('1' * 14, 2))`.
    const NODE_ID_LSBS: u64 = 0x3fff;
    /// $2^{14} - 1$, the maximum number of nodes that can be allocated
    /// for either node type.
    const N_NODES_MAX: u64 = 16383;

    // Constants <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Public functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Return a new AVL queue, optionally allocating inactive nodes.
    ///
    /// # Parameters
    ///
    /// * `sort_order`: `ASCENDING` or `DESCENDING`.
    /// * `n_inactive_tree_nodes`: The number of inactive tree nodes
    ///   to allocate.
    /// * `n_inactive_list_nodes`: The number of inactive list nodes
    ///   to allocate.
    ///
    /// # Returns
    ///
    /// * `AVLqueue<V>`: A new AVL queue.
    ///
    /// # Testing
    ///
    /// * `test_new_no_nodes()`
    /// * `test_new_some_nodes()`
    public fun new<V: store>(
        sort_order: bool,
        n_inactive_tree_nodes: u64,
        n_inactive_list_nodes: u64,
    ): AVLqueue<V> {
        // Assert not trying to allocate too many tree nodes.
        verify_node_count(n_inactive_tree_nodes);
        // Assert not trying to allocate too many list nodes.
        verify_node_count(n_inactive_list_nodes);
        // Initialize bits field based on sort order.
        let bits = if (sort_order == ASCENDING) AVLQ_BITS_ASCENDING else
            AVLQ_BITS_DESCENDING;
        // Mask in 1-indexed node ID at top of each inactive node stack.
        bits = bits
            | ((n_inactive_tree_nodes as u128) << AVLQ_BITS_TREE_TOP_SHIFT)
            | ((n_inactive_list_nodes as u128) << AVLQ_BITS_LIST_TOP_SHIFT);
        let avl_queue = AVLqueue{ // Declare empty AVL queue.
            bits,
            root_lsbs: 0,
            tree_nodes: table_with_length::new(),
            list_nodes: table_with_length::new(),
            values: table::new(),
        };
        // If need to allocate at least one tree node:
        if (n_inactive_tree_nodes > 0) {
            let i = 0; // Declare loop counter.
            // While nodes to allocate:
            while (i < n_inactive_tree_nodes) {
                // Add to tree nodes table a node having 1-indexed node
                // ID derived from counter, indicating next inactive
                // node in stack has ID of last allocated node (or null
                // in the case of the first loop iteration).
                table_with_length::add(&mut avl_queue.tree_nodes, i + 1,
                                       TreeNode{bits: (i as u128)});
                i = i + 1; // Increment loop counter.
            };
        };
        // If need to allocate at least one list node:
        if (n_inactive_list_nodes > 0) {
            let i = 0; // Declare loop counter.
            // While nodes to allocate:
            while (i < n_inactive_list_nodes) {
                // Add to list nodes table a node having 1-indexed node
                // ID derived from counter, indicating next inactive
                // node in stack has ID of last allocated node (or null
                // in the case of the first loop iteration).
                table_with_length::add(
                    &mut avl_queue.list_nodes, i + 1, ListNode{
                        last_msbs: 0,
                        last_lsbs: 0,
                        next_msbs: (i >> BITS_PER_BYTE as u8),
                        next_lsbs: (i & LEAST_SIGNIFICANT_BYTE as u8)});
                // Allocate optional insertion value entry.
                table::add(&mut avl_queue.values, i + 1, option::none());
                i = i + 1; // Increment loop counter.
            };
        };
        avl_queue // Return AVL queue.
    }

    /// Return `true` if given AVL queue has ascending sort order.
    ///
    /// # Testing
    ///
    /// * `test_is_ascending()`
    public fun is_ascending<V>(
        avl_queue_ref: &AVLqueue<V>
    ): bool {
        avl_queue_ref.bits & AVLQ_BITS_ASCENDING == AVLQ_BITS_ASCENDING
    }

    // Public functions <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Private functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    /// Verify node count is not too high.
    ///
    /// # Aborts
    ///
    /// * `E_TOO_MANY_NODES`: `n_nodes` is not less than `N_NODES_MAX`.
    ///
    /// # Testing
    ///
    /// * `test_verify_node_count_fail()`
    /// * `test_verify_node_count_pass()`
    fun verify_node_count(
        n_nodes: u64,
    ) {
        // Assert node count is less than or equal to max amount.
        assert!(n_nodes <= N_NODES_MAX, E_TOO_MANY_NODES);
    }

    // Private functions <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Test-only error codes >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test_only]
    /// When a char in a bytestring is neither 0 nor 1.
    const E_BIT_NOT_0_OR_1: u64 = 100;

    // Test-only error codes <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Test-only functions >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test_only]
    /// Immutably borrow list node having given node ID.
    fun borrow_list_node_test<V>(
        avl_queue_ref: &AVLqueue<V>,
        node_id: u64
    ): &ListNode {
        table_with_length::borrow(&avl_queue_ref.list_nodes, node_id)
    }

    #[test_only]
    /// Immutably borrow tree node having given node ID.
    fun borrow_tree_node_test<V>(
        avl_queue_ref: &AVLqueue<V>,
        node_id: u64
    ): &TreeNode {
        table_with_length::borrow(&avl_queue_ref.tree_nodes, node_id)
    }

    #[test_only]
    /// Immutably borrow value option having given node ID.
    fun borrow_value_option_test<V>(
        avl_queue_ref: &AVLqueue<V>,
        node_id: u64
    ): &Option<V> {
        table::borrow(&avl_queue_ref.values, node_id)
    }

    #[test_only]
    /// Return node ID at top of inactive list node stack indicated by
    /// given AVL queue.
    ///
    /// # Testing
    ///
    /// * `test_get_list_top_test()`
    fun get_list_top_test<V>(
        avl_queue_ref: &AVLqueue<V>
    ): u64 {
        (avl_queue_ref.bits >> AVLQ_BITS_LIST_TOP_SHIFT as u64) & NODE_ID_LSBS
    }

    #[test_only]
    /// Return node ID at top of inactive tree node stack indicated by
    /// given AVL queue.
    ///
    /// # Testing
    ///
    /// * `test_get_tree_top_test()`
    fun get_tree_top_test<V>(
        avl_queue_ref: &AVLqueue<V>
    ): u64 {
        (avl_queue_ref.bits >> AVLQ_BITS_TREE_TOP_SHIFT as u64) & NODE_ID_LSBS
    }


    #[test_only]
    /// Return node ID of next node (which may be a list node ID or a
    /// tree node ID), indicated by given list node.
    ///
    /// # Testing
    ///
    /// * `test_get_list_next_test()`
    fun get_list_next_test(
        list_node_ref: &ListNode
    ): u64 {
        ((list_node_ref.next_msbs as u64) << BITS_PER_BYTE |
            (list_node_ref.next_lsbs as u64)) & NODE_ID_LSBS
    }

    #[test_only]
    /// Return node ID of next inactive tree node in stack, indicated
    /// by given tree node.
    ///
    /// # Testing
    ///
    /// * `test_get_tree_next_test()`
    fun get_tree_next_test(
        tree_node_ref: &TreeNode
    ): u64 {
        ((tree_node_ref.bits & (HI_64 as u128) as u64) & NODE_ID_LSBS)
    }

    #[test_only]
    /// Return a `u128` corresponding to provided byte string `s`. The
    /// byte should only contain only "0"s and "1"s, up to 128
    /// characters max (e.g. `b"100101...10101010"`).
    ///
    /// # Testing
    ///
    /// * `test_u_128_64()`
    /// * `test_u_128_failure()`
    public fun u_128(
        s: vector<u8>
    ): u128 {
        let n = vector::length<u8>(&s); // Get number of bits.
        let r = 0; // Initialize result to 0.
        let i = 0; // Start loop at least significant bit.
        while (i < n) { // While there are bits left to review.
            // Get bit under review.
            let b = *vector::borrow<u8>(&s, n - 1 - i);
            if (b == 0x31) { // If the bit is 1 (0x31 in ASCII):
                // OR result with the correspondingly leftshifted bit.
                r = r | 1 << (i as u8);
            // Otherwise, assert bit is marked 0 (0x30 in ASCII).
            } else assert!(b == 0x30, E_BIT_NOT_0_OR_1);
            i = i + 1; // Proceed to next-least-significant bit.
        };
        r // Return result.
    }

    #[test_only]
    /// Return `u128` corresponding to concatenated result of `a`, `b`,
    /// `c`, and `d`. Useful for line-wrapping long byte strings, and
    /// inspection via 32-bit sections.
    ///
    /// # Testing
    ///
    /// * `test_u_128_64()`
    public fun u_128_by_32(
        a: vector<u8>,
        b: vector<u8>,
        c: vector<u8>,
        d: vector<u8>,
    ): u128 {
        vector::append<u8>(&mut c, d); // Append d onto c.
        vector::append<u8>(&mut b, c); // Append c onto b.
        vector::append<u8>(&mut a, b); // Append b onto a.
        u_128(a) // Return u128 equivalent of concatenated bytestring.
    }

    #[test_only]
    /// Wrapper for `u_128()`, casting return to `u64`.
    ///
    /// # Testing
    ///
    /// * `test_u_128_64()`
    public fun u_64(s: vector<u8>): u64 {(u_128(s) as u64)}

    #[test_only]
    /// Wrapper for `u_128_by_32()`, accepting only two inputs, with
    /// casted return to `u64`.
    public fun u_64_by_32(
        a: vector<u8>,
        b: vector<u8>
    ): u64 {
        // Get u128 for given inputs, cast to u64.
        (u_128_by_32(a, b, b"", b"") as u64)
    }

    // Test-only functions <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

    // Tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    #[test]
    /// Verify successful extraction.
    fun test_get_list_next_test() {
        // Declare list node.
        let list_node = ListNode{
            last_msbs: 0,
            last_lsbs: 0,
            next_msbs: (u_64(b"00101010") as u8),
            next_lsbs: (u_64(b"10101011") as u8)};
        assert!( // Assert next node ID.
            get_list_next_test(&list_node) == u_64(b"10101010101011"), 0);
        ListNode{last_msbs: _, last_lsbs: _, next_msbs: _, next_lsbs: _} =
            list_node; // Unpack list node.
    }

    #[test]
    /// Verify successful extraction.
    fun test_get_list_top_test():
    AVLqueue<u8> {
        let avl_queue = AVLqueue{ // Create empty AVL queue.
            bits: u_128_by_32(
                b"11111111111111111010101010101101",
                //                ^ bit 111    ^ bit 98
                b"11111111111111111111111111111111",
                b"11111111111111111111111111111111",
                b"11111111111111111111111111111111"),
            root_lsbs: 0,
            tree_nodes: table_with_length::new(),
            list_nodes: table_with_length::new(),
            values: table::new(),
        };
        // Assert list top.
        assert!(get_list_top_test(&avl_queue) == u_64(b"10101010101011"), 0);
        avl_queue // Return AVL queue.
    }

    #[test]
    /// Verify successful extraction.
    fun test_get_tree_next_test() {
        // Declare tree node.
        let tree_node = TreeNode{bits: u_128_by_32(
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111",
            b"11111111111111100010101010101011")};
        assert!( // Assert next node ID.
            get_tree_next_test(&tree_node) == u_64(b"10101010101011"), 0);
        TreeNode{bits: _} = tree_node; // Unpack tree node.
    }

    #[test]
    /// Verify successful extraction.
    fun test_get_tree_top_test():
    AVLqueue<u8> {
        let avl_queue = AVLqueue{ // Create empty AVL queue.
            bits: u_128_by_32(
                b"11101010101010110111111111111111",
                //  ^ bit 125    ^ bit 112
                b"11111111111111111111111111111111",
                b"11111111111111111111111111111111",
                b"11111111111111111111111111111111"),
            root_lsbs: 0,
            tree_nodes: table_with_length::new(),
            list_nodes: table_with_length::new(),
            values: table::new(),
        };
        // Assert tree top.
        assert!(get_tree_top_test(&avl_queue) == u_64(b"10101010101011"), 0);
        avl_queue // Return AVL queue.
    }

    #[test]
    /// Verify successful initialization for no node allocations.
    fun test_new_no_nodes(): (
        AVLqueue<u8>,
        AVLqueue<u8>
    ) {
        // Init ascending AVL queue.
        let avl_queue_ascending = new(ASCENDING, 0, 0);
        // Assert flagged ascending.
        assert!(is_ascending(&avl_queue_ascending), 0);
        // Assert null stack tops.
        assert!(get_list_top_test(&avl_queue_ascending) == NIL, 0);
        assert!(get_tree_top_test(&avl_queue_ascending) == NIL, 0);
        // Init descending AVL queue.
        let avl_queue_descending = new(DESCENDING, 0, 0);
        // Assert flagged descending.
        assert!(!is_ascending(&avl_queue_descending), 0);
        (avl_queue_ascending, avl_queue_descending) // Return both.
    }

    #[test]
    /// Verify successful initialization for allocating tree nodes.
    fun test_new_some_nodes(): (
        AVLqueue<u8>
    ) {
        // Init ascending AVL queue with two nodes each.
        let avlq = new(ASCENDING, 3, 2);
        // Assert table lengths.
        assert!(table_with_length::length(&avlq.tree_nodes) == 3, 0);
        assert!(table_with_length::length(&avlq.list_nodes) == 2, 0);
        // Assert stack tops.
        assert!(get_tree_top_test(&avlq) == 3, 0);
        assert!(get_list_top_test(&avlq) == 2, 0);
        // Assert inactive tree node stack next chain.
        assert!(get_tree_next_test(borrow_tree_node_test(&avlq, 3)) == 2, 0);
        assert!(get_tree_next_test(borrow_tree_node_test(&avlq, 2)) == 1, 0);
        assert!(get_tree_next_test(borrow_tree_node_test(&avlq, 1)) == NIL, 0);
        // Assert inactive list node stack next chain.
        assert!(get_list_next_test(borrow_list_node_test(&avlq, 2)) == 1, 0);
        assert!(get_list_next_test(borrow_list_node_test(&avlq, 1)) == NIL, 0);
        // Assert value options initialize to none.
        assert!(option::is_none(borrow_value_option_test(&avlq, 2)), 0);
        assert!(option::is_none(borrow_value_option_test(&avlq, 1)), 0);
        avlq // Return AVL queue.
    }

    #[test]
    /// Verify successful check.
    fun test_is_ascending():
    AVLqueue<u8> {
        let avl_queue = AVLqueue{ // Create empty AVL queue.
            bits: 0,
            root_lsbs: 0,
            tree_nodes: table_with_length::new(),
            list_nodes: table_with_length::new(),
            values: table::new(),
        };
        // Assert flagged descending.
        assert!(!is_ascending(&avl_queue), 0);
        // Flag as ascending.
        avl_queue.bits = u_128_by_32(
            b"01000000000000000000000000000000",
            // ^ bit 126
            b"00000000000000000000000000000000",
            b"00000000000000000000000000000000",
            b"00000000000000000000000000000000"
        );
        // Assert flagged descending.
        assert!(is_ascending(&avl_queue), 0);
        avl_queue // Return AVL queue.
    }

    #[test]
    /// Verify successful return values.
    fun test_u_128_64() {
        assert!(u_128(b"0") == 0, 0);
        assert!(u_128(b"1") == 1, 0);
        assert!(u_128(b"00") == 0, 0);
        assert!(u_128(b"01") == 1, 0);
        assert!(u_128(b"10") == 2, 0);
        assert!(u_128(b"11") == 3, 0);
        assert!(u_128(b"10101010") == 170, 0);
        assert!(u_128(b"00000001") == 1, 0);
        assert!(u_128(b"11111111") == 255, 0);
        assert!(u_128_by_32(
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111"
        ) == HI_128, 0);
        assert!(u_128_by_32(
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111110"
        ) == HI_128 - 1, 0);
        assert!(u_64(b"0") == 0, 0);
        assert!(u_64(b"0") == 0, 0);
        assert!(u_64(b"1") == 1, 0);
        assert!(u_64(b"00") == 0, 0);
        assert!(u_64(b"01") == 1, 0);
        assert!(u_64(b"10") == 2, 0);
        assert!(u_64(b"11") == 3, 0);
        assert!(u_64(b"10101010") == 170, 0);
        assert!(u_64(b"00000001") == 1, 0);
        assert!(u_64(b"11111111") == 255, 0);
        assert!(u_64_by_32(
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111111"
        ) == HI_64, 0);
        assert!(u_64_by_32(
            b"11111111111111111111111111111111",
            b"11111111111111111111111111111110"
        ) == HI_64 - 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = 100)]
    /// Verify failure for non-binary-representative byte string.
    fun test_u_128_failure() {u_128(b"2");}

    #[test]
    #[expected_failure(abort_code = 0)]
    /// Verify failure for too many nodes.
    fun test_verify_node_count_fail() {
        // Attempt invalid invocation for one too many nodes.
        verify_node_count(u_64(b"100000000000000"));
    }

    #[test]
    /// Verify maximum node count passes check.
    fun test_verify_new_node_id_pass() {
        // Attempt valid invocation for max node count.
        verify_node_count(u_64(b"11111111111111"));
    }

    // Tests <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

}