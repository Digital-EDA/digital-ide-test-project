# Ethernet0 EMIO/MII constraints from the supplied board reference.
# Active top must expose the system BD wrapper ports (system_wrapper).
# All Ethernet PL I/O below uses LVCMOS33.

set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_RX_CLK_0}]
set_property PACKAGE_PIN K17 [get_ports {ENET0_GMII_RX_CLK_0}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TX_CLK_0}]
set_property PACKAGE_PIN L14 [get_ports {ENET0_GMII_TX_CLK_0}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_RX_DV_0}]
set_property PACKAGE_PIN K18 [get_ports {ENET0_GMII_RX_DV_0}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[0]}]
set_property PACKAGE_PIN J14 [get_ports {enet0_gmii_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[1]}]
set_property PACKAGE_PIN K14 [get_ports {enet0_gmii_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[2]}]
set_property PACKAGE_PIN M18 [get_ports {enet0_gmii_rxd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[3]}]
set_property PACKAGE_PIN M17 [get_ports {enet0_gmii_rxd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property PACKAGE_PIN N16 [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[0]}]
set_property PACKAGE_PIN M14 [get_ports {enet0_gmii_txd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[1]}]
set_property PACKAGE_PIN L15 [get_ports {enet0_gmii_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[2]}]
set_property PACKAGE_PIN M15 [get_ports {enet0_gmii_txd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[3]}]
set_property PACKAGE_PIN N15 [get_ports {enet0_gmii_txd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MDIO_ETHERNET_0_0_mdio_io}]
set_property PACKAGE_PIN J15 [get_ports {MDIO_ETHERNET_0_0_mdio_io}]
set_property IOSTANDARD LVCMOS33 [get_ports {MDIO_ETHERNET_0_0_mdc}]
set_property PACKAGE_PIN G14 [get_ports {MDIO_ETHERNET_0_0_mdc}]
set_property IOSTANDARD LVCMOS33 [get_ports {ETH_RESET}]
set_property PACKAGE_PIN H20 [get_ports {ETH_RESET}]

set_property SLEW FAST [get_ports {enet0_gmii_txd[3]}]
set_property SLEW FAST [get_ports {enet0_gmii_txd[2]}]
set_property SLEW FAST [get_ports {enet0_gmii_txd[1]}]
set_property SLEW FAST [get_ports {enet0_gmii_txd[0]}]
set_property SLEW FAST [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property SLEW FAST [get_ports {MDIO_ETHERNET_0_0_mdio_io}]
set_property SLEW FAST [get_ports {MDIO_ETHERNET_0_0_mdc}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Previous func-only constraints, retained as a reference and intentionally inactive:
# set_property PACKAGE_PIN N18 [get_ports sys_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
# create_clock -name sys_clk -period 20.000 -waveform {0.000 10.000} [get_ports sys_clk]
# set_input_jitter [get_clocks sys_clk] 0.200
# 
# set_property PACKAGE_PIN P16 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
# 
# set_property PACKAGE_PIN P15 [get_ports {led[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
# set_property PACKAGE_PIN U12 [get_ports {led[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
