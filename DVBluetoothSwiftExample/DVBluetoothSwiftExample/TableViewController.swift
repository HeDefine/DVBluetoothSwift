//
//  TableViewController.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/13.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        BedManager.shared.delegate = self
    }

}

// MARK: - Button Event
extension TableViewController {
    @IBAction func refreshBtnClick(_ sender: Any) {
        BedManager.shared.scanPeripheral()
    }
}

// MARK: - Table view data source
extension TableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Connected" : "Searched"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ?
            BedManager.shared.connectedPeripherals.count :
            BedManager.shared.scannedPeripherals.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseId = "tableReuseId"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as? TableViewCell ?? TableViewCell.init()
        let peri = indexPath.section == 0 ?
            BedManager.shared.connectedPeripherals[indexPath.row] :
            BedManager.shared.scannedPeripherals[indexPath.row]
        cell.nameLbl.text = peri.name
        cell.uuidLbl.text = peri.identifier
        cell.rssiLbl.text = "信号:\(peri.RSSI)"
        cell.servicesLbl.text = "服务数"
        cell.accessoryType = peri.isConnected ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let peri = indexPath.section == 0 ?
            BedManager.shared.connectedPeripherals[indexPath.row] :
            BedManager.shared.scannedPeripherals[indexPath.row]
        if indexPath.section == 0 {
            BedManager.shared.disConnect(to: peri)
        } else {
            BedManager.shared.connect(to: peri)
        }
    }
}

// MARK: - DVBleManagerDelegate
extension TableViewController: DVBleManagerDelegate {
    func manager(_ manager: DVBleManager, didBluetoothStateChanged state: DVBleManagerState) {
        switch state {
        case .powerOn:
            break
        case .powerOff:
            tableView.reloadData()
            break
        default:
            break
        }
    }
    
    func manager(_ manager: DVBleManager, didScanPeripheral newPeripheral: DVBlePeripheral?, state: DVBleManagerScanState) {
        switch state {
        case .begin:
            tableView.reloadData()
            break
        case .scanning:
            tableView.reloadData()
            break
        default:
            break
        }
    }
    
    func manager(_ manager: DVBleManager, didConnectToPeripheral peripheral: DVBlePeripheral, state: DVBleManagerConnectState) {
        switch state {
        case .begin:
            tableView.reloadData()
            break
        case .success:
            tableView.reloadData()
            break
        default:
            break
        }
    }
    
    func manager(_ manager: DVBleManager, didConnectFailedToPeripheral peripheral: DVBlePeripheral, error: DVBleManagerConnectError) {
        
    }
    
    func manager(_ manager: DVBleManager, didDisConnectToPeripheral peripheral: DVBlePeripheral, isActive: Bool) {
        tableView.reloadData()
    }
    
    func manager(_ manager: DVBleManager, didReconnectToPeripherals peripherals: [DVBlePeripheral]?, state: DVBleManagerReconnectState) {
        
    }
    
    
}
