module.exports = {
    docs: [
        'welcome',
        {
            type: 'category',
            label: 'Move modules',
            link: {
                type: 'doc',
                id: 'move/modules'
            },
            items: [
                'move/changelog'
            ]
        },
        {
            type: 'category',
            label: 'Design overview',
            link: {
                type: 'doc',
                id: 'overview/index'
            },
            items: [
                'overview/orders',
                'overview/registry',
                'overview/incentives',
                'overview/market-accounts',
                'overview/matching'
            ]
        },
        {
            type: 'category',
            label: 'Move APIs',
            link: {
                type: 'doc',
                id: 'apis/index'
            },
            items: [
                'apis/registration',
                'apis/assets',
                'apis/trading',
                'apis/integrators',
                'apis/utility'
            ]
        },
        {
            type: 'category',
            label: 'Off-chain interfaces',
            link: {
                type: 'generated-index'
            },
            items: [
                'off-chain/apis',
                'off-chain/events',
                'off-chain/python-sdk',
                'off-chain/rust-sdk'
            ]
        },
        {
            type: 'category',
            label: 'Integrator resources',
            link: {
                type: 'generated-index'
            },
            items: [
                'integrators/econia-labs',
                {
                    type: 'category',
                    label: 'Oracles',
                    link: {
                        type: 'generated-index'
                    },
                    items: [
                        'integrators/oracles/pyth',
                    ]
                },
                'integrators/bridges',
                'integrators/notifications',
            ]
        },
        'security',
        'logo',
        'glossary'
    ]
}