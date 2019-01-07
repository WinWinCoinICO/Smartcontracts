module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 7545,
            network_id: "*",
        },
        main: {
            host: "localhost",
            port: 8545,
            network_id: 1,
            gas: 7800000,
            gasPrice: 20000000000
        }
    }
};