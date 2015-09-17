//
//  P2PCommunicationCenter.m
//  BluetoothChatDemo
//
//  Created by tmy on 14-6-30.
//  Copyright (c) 2014年 hurray. All rights reserved.
//

#import "P2PCommunicationCenter.h"
#import "P2PTransmitOperation.h"
#import "P2PDataPacket.h"
#import "NSString+P2PMD5.h"

NSString *const P2PChatInfoUserDeviceIdentifierKey = @"P2PChatInfoUserDeviceIdentifierKey";
NSString *const P2PInvitationContextNonceKey = @"P2PInvitationContextNonceKey";

#define ADVERTISE_NAME @"default-name"
#define SERVICE_UUID @"15DD8179-4C05-46D5-A5FA-1821938AF551"
#define CHARACTERISTIC_CHAT_UUID @"6FAFD270-C748-4FDA-8606-B3CCC6660FCD"
#define CHARACTERISTIC_CHAT_UUID_WRITE @"0C0D8CB8-4F33-4FF2-A870-B619A91FB4E5"
#define CHARACTERISTIC_INFO_UUID @"C1DAB8EA-C527-468F-BA0F-1E429D283327"
#define CHARACTERISTIC_INFO_UUID_READ @"A611FDB2-1499-44EC-B7A1-88F75BDA8CF7"

#define IBEACON_UUID @"6AA877AC-C949-492E-B21B-11245D9BFB6C"
#define IBEACON_IDENTIFIER @"com.default.test"


#define MAX_CONNECT_COUNT 7
#define CONNECT_TIMEOUT 15
#define MAX_SPREAD_COUNT 3
#define SWITCH_TIME_INTERVAL 7
#define IBEACON_ADVERTISE_TIME 3
#define IBEACON_ADVERTISE_WAIT_TIME 30

#ifndef DEBUG
#define NSLog(format, ...)
#endif

typedef enum {
    P2PCommunicationRoleNone = 0,
    P2PCommunicationRolePeripheral,
    P2PCommunicationRoleCentral
}P2PCommunicationRole;

@implementation P2PCommunicationCenter
{
    NSString                    *_advertiseName;
    NSString                    *_serviceIdentifier;

    NSMutableDictionary         *_chatInfo;
    NSString                    *_deviceIdentifier;
    
    
    CBMutableService            *_chatService;
    CBMutableCharacteristic     *_chatContentCharacteristic;
    CBMutableCharacteristic     *_chatContentCharacteristicForWrite;
    CBMutableCharacteristic     *_identifierCharacteristicForWrite;
    CBMutableCharacteristic     *_identifierCharacteristicForRead;
    CBCentralManager            *_centralManager;
    CBPeripheralManager         *_peripheralManager;
    CBPeripheralManager         *_iBeaconPeripheralManager;

    P2PCommunicationRole        _role;
    
    __weak NSTimer              *_iBeaconTimer;
    __weak NSTimer              *_switchTimer;
    __weak NSTimer              *_checkRoleTimer;
    dispatch_queue_t            _callbackQueue;
    NSMutableSet                *_receivedMessageIdentifiers;
    
    NSMutableDictionary         *_connectedDevices;
    NSMutableDictionary         *_existPeripherals;
    NSMutableDictionary         *_existCentrals;
    NSMutableSet                *_existenceDevices;
    NSMutableDictionary         *_onlineRelationDict;
    
    NSOperationQueue            *_sendOperationQueue;
    NSMutableDictionary         *_receiveBufferDict;

    CLLocationManager           *_locationManager;
    CLBeaconRegion              *_beaconRegion;
    NSDictionary                *_iBeaconDataDict;
    
    UIBackgroundTaskIdentifier    _backgroundTaskIdentifier;
    
    BOOL                          _isCommunicationStarted;
    BOOL                          _shouldAdvertiseViaPeripheral;
    BOOL                          _shouldScanDevice;
    BOOL                          _shouldAdvertiseViaIBeacon;
    BOOL                          _hasAddedAdvertisementService;
    BOOL                          _hasNewPeripheralsConnected;
    BOOL                          _hasNewCentralConnected;
}
@synthesize deviceIdentifier = _deviceIdentifier;

+ (instancetype)sharedCenter
{
    static P2PCommunicationCenter *SharedCenter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SharedCenter = [[self alloc] init];
    });
    
    return SharedCenter;
}

- (void)setAdvertiseName:(NSString *)advertiseName
{
    if(_advertiseName != advertiseName){
        _advertiseName = advertiseName;
    }
}

- (id)init
{
    if(self = [super init]){
        self.advertiseName = ADVERTISE_NAME;
        self.serviceIdentifier = SERVICE_UUID;
        self.iBeaconUUID = IBEACON_UUID;
        self.iBeaconIdentifier = IBEACON_IDENTIFIER;
        self.shouldConnectViaiBeacon = NO;
        self.shouldSpreadMessages = NO;
        self.iBeaconEnabled = NO;
        _hasAddedAdvertisementService = NO;
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        
        _callbackQueue = dispatch_queue_create("com.p2pcommunication.callbackqueue", NULL);
      
        _deviceIdentifier = [[[[UIDevice currentDevice] identifierForVendor] UUIDString] md5ValueForP2P];
        _chatInfo = [[NSMutableDictionary alloc] init];
        
        _connectedDevices = [[NSMutableDictionary alloc] initWithCapacity:50];
        _existenceDevices = [[NSMutableSet alloc] initWithCapacity:100];
        _existPeripherals = [[NSMutableDictionary alloc] initWithCapacity:100];
        _existCentrals = [[NSMutableDictionary alloc] initWithCapacity:100];
        
        _onlineRelationDict = [[NSMutableDictionary alloc] initWithCapacity:100];
        _receivedMessageIdentifiers = [[NSMutableSet alloc] init];
 
        _receiveBufferDict = [NSMutableDictionary dictionaryWithCapacity:20];
        _sendOperationQueue = [[NSOperationQueue alloc] init];
        [_sendOperationQueue setMaxConcurrentOperationCount:1];
        
        [self initLocation];
 
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:[UIApplication sharedApplication]];
        
    }
    
    return self;
}


- (void)appDidEnterBackground:(NSNotification *)notification
{
    if (self.iBeaconEnabled) {
        [self startScanViaIBeacon];
        [self stopAdvertisingViaIBeacon];
        if(_iBeaconTimer) {
            [_iBeaconTimer invalidate];
            _iBeaconTimer = nil;
        }
    }
}

- (void)appDidEnterForeground:(NSNotification *)notification
{
    if (self.iBeaconEnabled) {
        [self stopScanViaIBeacon];
        [self performSelector:@selector(handleForIBeaconAdvertise) withObject:nil afterDelay:3];
    }
}

- (void)appWillTerminate:(NSNotification *)notification
{
    if (self.iBeaconEnabled) {
        [self startScanViaIBeacon];
    }
    [self disconnect];
}

- (void)setupChatInfo:(NSDictionary *)chatInfo
{
    [_chatInfo addEntriesFromDictionary:chatInfo];
}

- (void)initPeripheral
{
    CBUUID *serviceUUID = [CBUUID UUIDWithString:self.serviceIdentifier];
    _chatService = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
    
    CBUUID *characteristicChatUUID = [CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID];
    _chatContentCharacteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicChatUUID properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    
    CBUUID *characteristicChatForWriteUUID = [CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID_WRITE];
    _chatContentCharacteristicForWrite = [[CBMutableCharacteristic alloc] initWithType:characteristicChatForWriteUUID properties:CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsWriteable];
    
    CBUUID *characteristicInfoUUID = [CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID];
    _identifierCharacteristicForWrite = [[CBMutableCharacteristic alloc] initWithType:characteristicInfoUUID properties: CBCharacteristicPropertyWriteWithoutResponse value:nil permissions: CBAttributePermissionsWriteable];
    
    CBUUID *characteristicInfoUUIDRead = [CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID_READ];
    _identifierCharacteristicForRead = [[CBMutableCharacteristic alloc] initWithType:characteristicInfoUUIDRead properties: CBCharacteristicPropertyRead value:[_deviceIdentifier dataUsingEncoding:NSUTF8StringEncoding] permissions: CBAttributePermissionsReadable];
    
    
    [_chatService setCharacteristics:@[_identifierCharacteristicForWrite, _identifierCharacteristicForRead, _chatContentCharacteristic, _chatContentCharacteristicForWrite]];
    
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:_callbackQueue];
}

- (void)initCentral
{
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_callbackQueue];
}

- (void)initIBeaconPeripheral
{
    NSUUID *iBeaconUUID = [[NSUUID alloc] initWithUUIDString:self.iBeaconUUID];
    CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:iBeaconUUID identifier:self.iBeaconIdentifier];

    _iBeaconDataDict = [beaconRegion peripheralDataWithMeasuredPower:nil];
    
    _iBeaconPeripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:_callbackQueue options:nil];
}

- (void)initLocation
{
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    [_locationManager startUpdatingLocation];
    [_locationManager stopUpdatingLocation];
}

#pragma mark Advertising/Scan Device

- (void)startCommunication
{
    _isCommunicationStarted = YES;
    if(_role == P2PCommunicationRoleNone){
        [self startConsultingForCommunication];
    }else if (_role == P2PCommunicationRoleCentral){
        [self startScanningDevices];
    }else if (_role == P2PCommunicationRolePeripheral){
        [self startAdvertising];
    }
    
    if(self.iBeaconEnabled){
        [self performSelector:@selector(handleForIBeaconAdvertise) withObject:nil afterDelay:3];
    }
}

- (void)stopCommunication
{
    _isCommunicationStarted = NO;
    if(_role == P2PCommunicationRoleNone || _role == P2PCommunicationRoleCentral){
        [self stopScanning];
    }else if (_role == P2PCommunicationRolePeripheral){
        [self stopAdvertising];
    }
    
    if(self.iBeaconEnabled){
        if (_shouldAdvertiseViaIBeacon) {
            [self stopAdvertisingViaIBeacon];
        }
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleForIBeaconAdvertise) object:nil];
        if(_iBeaconTimer){
            [_iBeaconTimer invalidate];
            _iBeaconTimer = nil;
        }
    }
}

- (void)startConsultingForCommunication
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _role = P2PCommunicationRoleNone;
        
        if(_shouldAdvertiseViaPeripheral){
            [self stopAdvertising];
        }
        
        if(!_shouldScanDevice){
            [self startScanningDevices];
        }
        
        NSTimeInterval randomScanTime =  2 + (arc4random() % 7 + 1);
        _checkRoleTimer = [NSTimer scheduledTimerWithTimeInterval:randomScanTime target:self selector:@selector(handleRoleCheck) userInfo:nil repeats:NO];
        
        NSLog(@"start consulting %0.0f...", randomScanTime);

    });
}

- (void)stopConsultingForCommunication
{
    if(_checkRoleTimer){
        [_checkRoleTimer invalidate];
        _checkRoleTimer = nil;
    }
}

- (void)startAdvertising
{
    _shouldAdvertiseViaPeripheral = YES;
    
    if(!_peripheralManager){
        [self initPeripheral];
    }
    
    if(_peripheralManager.state == CBPeripheralManagerStatePoweredOn){
        if (!_hasAddedAdvertisementService) {
            _hasAddedAdvertisementService = YES;
            [_peripheralManager addService:_chatService];
        }else {
            NSMutableDictionary *advertiseDict = [@{CBAdvertisementDataLocalNameKey: self.advertiseName, CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:_serviceIdentifier]]} mutableCopy];
            
            [_peripheralManager startAdvertising: advertiseDict];
            
            NSLog(@"peripheralManager start advertising...");
        }
    }
}

- (void)stopAdvertising
{
    _shouldAdvertiseViaPeripheral = NO;
    [_peripheralManager stopAdvertising];
    NSLog(@"stop advertsing....");
}

- (void)startScanningDevices
{
    _shouldScanDevice = YES;
    
    if(!_centralManager){
        [self initCentral];
    }
    
    if(_centralManager.state == CBCentralManagerStatePoweredOn){
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:self.serviceIdentifier]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @(YES)}];
        NSLog(@"start scanning via central, service %@",self.serviceIdentifier);
    }
}

- (void)stopScanning
{
    _shouldScanDevice = NO;
    [_centralManager stopScan];
    NSLog(@"stop scanning...");
}

- (void)startAdvertisingViaIBeacon
{
    _shouldAdvertiseViaIBeacon = YES;
    if(!_iBeaconPeripheralManager){
        [self initIBeaconPeripheral];
    }
    
    if(_iBeaconPeripheralManager.state == CBPeripheralManagerStatePoweredOn){
        [_iBeaconPeripheralManager startAdvertising:_iBeaconDataDict];
    }
}

- (void)stopAdvertisingViaIBeacon
{
    _shouldAdvertiseViaIBeacon = NO;
    
    [_iBeaconPeripheralManager stopAdvertising];
    NSLog(@"stop iBeacon advertising...");
}

- (void)startScanViaIBeacon
{
    if(!_beaconRegion){
        NSUUID *iBeaconUUID = [[NSUUID alloc] initWithUUIDString:self.iBeaconUUID];
        _beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:iBeaconUUID identifier:self.iBeaconIdentifier];
    }
    
    [_locationManager startMonitoringForRegion:_beaconRegion];
    NSLog(@"start iBeacon Monitor...");
}

- (void)stopScanViaIBeacon
{
    [_locationManager stopMonitoringForRegion:_beaconRegion];
}

- (void)handleRoleCheck
{
    if(_role == P2PCommunicationRoleNone){
        _role = P2PCommunicationRolePeripheral;
        [self stopScanning];
        _centralManager = nil;
        [self startAdvertising];
    }
    
    NSLog(@"check role");
}

- (void)handleSwitchForAdvertiseScan
{
    int switchFlag = arc4random() % 2;
    if(switchFlag == 0){
        [self stopAdvertising];
        [self startScanningDevices];
        
    }else{
        [self stopScanning];
        [self startAdvertising];
    }
    
    _switchTimer = [NSTimer scheduledTimerWithTimeInterval:SWITCH_TIME_INTERVAL target:self selector:@selector(handleSwitchForAdvertiseScan) userInfo:nil repeats:NO];
}

- (void)handleForIBeaconAdvertise
{
    if(_shouldAdvertiseViaIBeacon){
        [self stopAdvertisingViaIBeacon];
        _iBeaconTimer = [NSTimer scheduledTimerWithTimeInterval:IBEACON_ADVERTISE_WAIT_TIME target:self selector:@selector(handleForIBeaconAdvertise) userInfo:nil repeats:NO];
    }else{
        [self startAdvertisingViaIBeacon];
        _iBeaconTimer = [NSTimer scheduledTimerWithTimeInterval:IBEACON_ADVERTISE_TIME target:self selector:@selector(handleForIBeaconAdvertise) userInfo:nil repeats:NO];
    }
}
 

#pragma mark Send/Receive Messages


- (void)sendMessage:(P2PMessage *)message
{
    message.originDeviceIdentifier = _deviceIdentifier;

    [_receivedMessageIdentifiers addObject:message.messageIdentifier];
    
    if(!message.toDeviceIdentifier){
        [self sendMessage:message toDevices:_connectedDevices.allValues];
    }else{
        P2PDevice *targetDevice = _connectedDevices[message.toDeviceIdentifier];
        if(targetDevice){
            [self sendMessage:message toDevices:@[targetDevice]];
        }else if([_existenceDevices containsObject:message.toDeviceIdentifier]){
            NSMutableSet *onlineRelationSet = _onlineRelationDict[message.toDeviceIdentifier];
            if(onlineRelationSet){
                NSString *connectedIdentifier = [onlineRelationSet anyObject];
                if(connectedIdentifier){
                    P2PDevice *device = _connectedDevices[connectedIdentifier];
                    if(device){
                        [self sendMessage:message toDevices:@[device]];
                    }
                }
            }
        }
    }
}

- (void)sendMessage:(P2PMessage *)message toDevices:(NSArray *)devices
{
    if(devices.count == 0)
        return;
    
    message.fromDeviceIdentifier = _deviceIdentifier;
    NSData *sendData = [message dataToSend];
    P2PTransmitOperation *sendOperation = nil;
    
    if(_role == P2PCommunicationRolePeripheral){
        NSMutableArray *centrals = [[NSMutableArray alloc] init];
        for (P2PDevice *device in devices) {
            if(device.isConnected){
                [centrals addObject:device.relatedCentral];
            }
        }
        
        P2PDataPacket *packet = [P2PDataPacket packetWithData:sendData];
        sendOperation = [P2PTransmitOperation operationWithPeripheralManager:_peripheralManager characteristic:_chatContentCharacteristic packet:packet centrals:centrals];
        [_sendOperationQueue addOperation:sendOperation];
    }else if(_role == P2PCommunicationRoleCentral){
        for (P2PDevice *device in devices) {
            if(device.isConnected){
                P2PDataPacket *packet = [P2PDataPacket packetWithData:sendData];
                sendOperation = [P2PTransmitOperation operationWithPeripheral:device.relatedPeripheral characteristic:device.chatCharacteristicForWrite packet:packet];
                [_sendOperationQueue addOperation:sendOperation];
            }
        }
    }
}

- (void)spreadMessage:(P2PMessage *)message
{
    if(message.spreadCount < MAX_SPREAD_COUNT){
        message.spreadCount ++;
        NSString *lastFromDevice = message.fromDeviceIdentifier;
        NSString *originalDevice = message.originDeviceIdentifier;
        NSMutableArray *devices = [[NSMutableArray alloc] init];
        for (NSString *identifier in _connectedDevices.allKeys) {
            if(![identifier isEqualToString:lastFromDevice] && ![identifier isEqualToString:originalDevice]){
                [devices addObject:_connectedDevices[identifier]];
            }
        }
        
        [self sendMessage:message toDevices:devices];
    }
}

- (void)handleForCommunicationSwitch {
    if(_role == P2PCommunicationRolePeripheral){
        if (_connectedDevices.count > 0 && _connectedDevices.count < MAX_CONNECT_COUNT && !_shouldAdvertiseViaPeripheral) {
            [self startAdvertising];
        }else if(_connectedDevices.count == 0){
            [self startConsultingForCommunication];
        }
    }else if(_role == P2PCommunicationRoleCentral){
        if(_connectedDevices.count == 0){
            [self startConsultingForCommunication];
        }else if(_connectedDevices.count > 0 && !_shouldScanDevice) {
            [self startScanningDevices];
        }
    }
}

- (void)handleReceivedPacket:(NSData *)packetData fromCentral:(CBCentral *)central
{
    NSMutableData *receiveBuffer = nil;
    if(!_receiveBufferDict[central.identifier.UUIDString]){
        receiveBuffer = [[NSMutableData alloc] init];
        _receiveBufferDict[central.identifier.UUIDString] = receiveBuffer;
    }else{
        receiveBuffer = _receiveBufferDict[central.identifier.UUIDString];
    }
    
    [self handleReceivedPacket:packetData withReceiveBuffer:receiveBuffer];
}

- (void)handleReceivedPacket:(NSData *)packetData fromPeripheral:(CBPeripheral *)peripheral
{
    NSMutableData *receiveBuffer = nil;
    if(!_receiveBufferDict[peripheral.identifier.UUIDString]){
        receiveBuffer = [[NSMutableData alloc] init];
        _receiveBufferDict[peripheral.identifier.UUIDString] = receiveBuffer;
    }else{
        receiveBuffer = _receiveBufferDict[peripheral.identifier.UUIDString];
    }
    
    [self handleReceivedPacket:packetData withReceiveBuffer:receiveBuffer];
}

- (void)handleReceivedPacket:(NSData *)packetData withReceiveBuffer:(NSMutableData *)receiveBuffer
{
    BOOL isTerminal = NO;
    if(packetData.length == 1){
        NSString *strValue = [[NSString alloc] initWithData:packetData encoding:NSUTF8StringEncoding];
        if([strValue isEqualToString:@"\0"]){
            isTerminal = YES;
        }
    }
    
    if(isTerminal){
        P2PMessage *message = [P2PMessage messageWithJsonData:receiveBuffer];
        if(message.type == P2PMessageTypeChat){
            [self handleChatMessage:message];
        }else if(message.type == P2PMessageTypeSyncOnline){
            [self handleOnlineSyncMessage:message];
        }
        
        
        [receiveBuffer setData:[[NSData alloc] init]];
    }else{
        [receiveBuffer appendData:packetData];
    }

}

- (void)handleChatMessage:(P2PMessage *)receiveMessage
{
    if(![receiveMessage.originDeviceIdentifier isEqualToString:receiveMessage.fromDeviceIdentifier]){
        NSLog(@"receivce spread message");
    }else{
        NSLog(@"receivce message");
    }
    
    BOOL isReceivedAlready = [_receivedMessageIdentifiers containsObject:receiveMessage.messageIdentifier];
    if(receiveMessage && !isReceivedAlready){
        [_receivedMessageIdentifiers addObject:receiveMessage.messageIdentifier];
        
        BOOL isTargetSelf = (receiveMessage.toDeviceIdentifier && [receiveMessage.toDeviceIdentifier isEqualToString:_deviceIdentifier]);
        BOOL shouldReceive = (!receiveMessage.toDeviceIdentifier || isTargetSelf);
        
        if(shouldReceive && self.delegate && [self.delegate respondsToSelector:@selector(P2PCommunicationCenter:didReceiveMessage:)]){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate P2PCommunicationCenter:self didReceiveMessage:receiveMessage];
            });
        }
        
        if(self.shouldSpreadMessages && !isTargetSelf){
            P2PMessage *spreadMessage = [receiveMessage copy];
            [self spreadMessage:spreadMessage];
        }
    }else{
        NSLog(@"ignore spread message");
    }
}

- (void)handleOnlineSyncMessage:(P2PMessage *)message
{
    if(![message.originDeviceIdentifier isEqualToString:message.fromDeviceIdentifier]){
        NSString *identifier = message.originDeviceIdentifier;
        BOOL isReceivedAlready = [_receivedMessageIdentifiers containsObject:message.messageIdentifier];
        if(!message || !message.content || isReceivedAlready)
            return;
        
        BOOL isOnline = [message.content boolValue];
        
        NSLog(@"receive online sync message %@ %d", identifier, isOnline);
        P2PDevice *syncDevice = [[P2PDevice alloc] init];
        syncDevice.identifier = identifier;
        
        if(isOnline){
            NSMutableSet  *relationOnlineSet = _onlineRelationDict[identifier];
            if(!relationOnlineSet){
                relationOnlineSet = [[NSMutableSet alloc] init];
                _onlineRelationDict[identifier] = relationOnlineSet;
            }
            
            if(![relationOnlineSet containsObject:message.fromDeviceIdentifier]){
                [relationOnlineSet addObject:message.fromDeviceIdentifier];
            }
        }
        
        if(isOnline && ![_existenceDevices containsObject:identifier]){
            [self handleForDeviceConnect:syncDevice isDirect:NO];
            if(![message.toDeviceIdentifier isEqualToString:_deviceIdentifier]){
                P2PMessage *selfExistMessage = [P2PMessage messageForSyncDeviceOnline:YES];
                selfExistMessage.toDeviceIdentifier = identifier;
                [self sendMessage:selfExistMessage];
            }
        }else if(!isOnline && [_existenceDevices containsObject:identifier]){
            
            NSMutableSet *relationSet = _onlineRelationDict[identifier];
            if(relationSet && [relationSet containsObject: message.fromDeviceIdentifier]){
                [relationSet removeObject:message.fromDeviceIdentifier];
                if([relationSet count] == 0){
                    [_onlineRelationDict removeObjectForKey:identifier];
                    
                    if(!_connectedDevices[identifier]){
                        [self handleForDeviceDisconnect:syncDevice isDirect:NO];
                    }
                }
            }
        }
    }
    
    if(self.shouldSpreadMessages){
        [self spreadMessage:message];
    }
}

- (void)handleForDeviceConnect:(P2PDevice *)device isDirect:(BOOL)isDirect
{
    if(isDirect && _role == P2PCommunicationRolePeripheral && _connectedDevices.count >= MAX_CONNECT_COUNT){
        [self stopAdvertising];
    }
    
    device.isConnected = YES;
    if(![_existenceDevices containsObject:device.identifier]){
        [_existenceDevices addObject:device.identifier];
        if(self.delegate && [self.delegate respondsToSelector:@selector(P2PCommunicationCenter:didConnectDevice:error:)]){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate P2PCommunicationCenter:self didConnectDevice:device error:nil];
                NSLog(@"connect to new device %@", device.identifier);
            });
        }
        
        if(isDirect){
            P2PMessage *message = [P2PMessage messageForSyncDeviceOnline:YES];
            message.fromDeviceIdentifier = device.identifier;
            message.originDeviceIdentifier = device.identifier;
            [self spreadMessage:message];
            NSLog(@"send sync online");
        }
    }
}

- (void)handleForDeviceDisconnect:(P2PDevice *)device isDirect:(BOOL)isDirect
{
    if(isDirect){
        [self handleForCommunicationSwitch];
    }
     
    
    device.isConnected = NO;

    BOOL isConnectedViaRelation = (_onlineRelationDict[device.identifier]? YES : NO);
    
    if(!isConnectedViaRelation && [_existenceDevices containsObject:device.identifier]){
        [_existenceDevices removeObject:device.identifier];
        
        if(self.delegate && [self.delegate respondsToSelector:@selector(P2PCommunicationCenter:didDisconnectDevice:)]){
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate P2PCommunicationCenter:self didDisconnectDevice:device];
                NSLog(@"disconnect to device %@", device.identifier);
            });
        }
    }else{
        NSLog(@"ignore disconnect %@", device.identifier);
    }
    
    if(isDirect){
        P2PMessage *message = [P2PMessage messageForSyncDeviceOnline:NO];
        message.fromDeviceIdentifier = device.identifier;
        message.originDeviceIdentifier = device.identifier;
        [self spreadMessage:message];
        NSLog(@"send sync offline");
        
        NSArray *relationKeys = [_onlineRelationDict.allKeys copy];
        for (NSString *identifier in relationKeys) {
            NSMutableSet *onlineRelationSet = _onlineRelationDict[identifier];
            if([onlineRelationSet containsObject:device.identifier]){
                [onlineRelationSet removeObject:device.identifier];
                if(onlineRelationSet.count == 0){
                    [_onlineRelationDict removeObjectForKey:identifier];

                    if(!_connectedDevices[identifier] && self.delegate && [self.delegate respondsToSelector:@selector(P2PCommunicationCenter:didDisconnectDevice:)]){
                        P2PDevice *device = [[P2PDevice alloc] init];
                        device.identifier = identifier;
                        
                        [self handleForDeviceDisconnect:device isDirect:NO];
                    }
                }
            }
        }
    }
}

- (void)disconnect
{
    NSMutableArray *relationDevices = [[NSMutableArray alloc] init];
    for (NSString *identifier in _existenceDevices) {
        if(!_connectedDevices[identifier]){
            P2PDevice *device = [[P2PDevice alloc] init];
            device.identifier = identifier;
            [relationDevices addObject:device];
        }
    }
    
    [_existenceDevices removeAllObjects];

    for (P2PDevice *device in relationDevices) {
        [self handleForDeviceDisconnect:device isDirect:NO];
    }
    
    for (P2PDevice *device in _connectedDevices.allValues) {
        [self disconnectToDevice:device.identifier];
    }
}


- (void)disconnectToDevice:(NSString *)deviceIdentifier
{
    if(_existPeripherals[deviceIdentifier]){
        [_existPeripherals removeObjectForKey:deviceIdentifier];
    }
    
    P2PDevice *device = _connectedDevices[deviceIdentifier];
    if(device.relatedPeripheral){
        [_centralManager cancelPeripheralConnection:device.relatedPeripheral];
    }
}

- (P2PDevice *)deviceForPeripheral:(CBPeripheral *)peripheral
{
    P2PDevice *existDevice = nil;
    for (P2PDevice *device in _connectedDevices.allValues) {
        if(device.relatedPeripheral == peripheral){
            existDevice = device;
            break;
        }
    }
    
    return existDevice;
}

- (P2PDevice *)deviceForCentral:(CBCentral *)central
{
    P2PDevice *existDevice = nil;
    for (P2PDevice *device in _connectedDevices.allValues) {
        if(device.relatedCentral == central){
            existDevice = device;
            break;
        }
    }
    
    return existDevice;
}

#pragma mark CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"central state changed to: %d", (int)central.state);
    
    if(central.state == CBCentralManagerStatePoweredOn && _shouldScanDevice){
        [self startScanningDevices];
    }else if((central.state == CBCentralManagerStatePoweredOff || central.state == CBCentralManagerStateUnauthorized || central.state == CBCentralManagerStateUnsupported) && _shouldScanDevice){
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if(_existPeripherals[peripheral.identifier.UUIDString])
        return;
    
    NSLog(@"discovered peripheral: %@  %@", peripheral.name, peripheral.identifier.UUIDString);
    
    if(_role == P2PCommunicationRoleNone){
        _role = P2PCommunicationRoleCentral;
        
        [self stopConsultingForCommunication];
        
        if(_shouldAdvertiseViaPeripheral){
            [self stopAdvertising];
        }
    }
    
    if(_isCommunicationStarted){
        [self stopCommunication];
    }
    
    peripheral.delegate = self;
    _existPeripherals[peripheral.identifier.UUIDString] = peripheral;
    [central connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"connected peripheral:%@ \n %@", peripheral.name, peripheral.identifier.UUIDString);
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:self.serviceIdentifier]]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"connect failed to peripheral %@ with error %@", peripheral.name, error.description);
    
    if(_existPeripherals[peripheral.identifier.UUIDString]){
        [_existPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
    }
    
    [self handleForCommunicationSwitch];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    @synchronized(self){
        if(_existPeripherals[peripheral.identifier.UUIDString]){
            [_existPeripherals removeObjectForKey:peripheral.identifier.UUIDString];
        }
        
        P2PDevice *device = [self deviceForPeripheral:peripheral];
        if(device){
            [_connectedDevices removeObjectForKey:device.identifier];
            if(device.isConnected){
                [self handleForDeviceDisconnect:device isDirect:YES];
            }else {
                [self handleForCommunicationSwitch];
            }
        }else {
            [self handleForCommunicationSwitch];
        }
    }
    
    NSLog(@"disconnect peripheral %@ with error %@", peripheral.name, error.description);
}

#pragma mark CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if(!error){
        NSLog(@"did discover services for peripheral %@\n%@", peripheral.name, peripheral.identifier.UUIDString);
        
        for (CBService *service in peripheral.services) {
            if([service.UUID isEqual:[CBUUID UUIDWithString:self.serviceIdentifier]]){
                [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID], [CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID_READ], [CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID], [CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID_WRITE]] forService:service];
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if(!error){
        NSLog(@"did discover characteristic for peripheral %@\n%@", peripheral.name, peripheral.identifier);
        
        @synchronized(self){
            for (CBCharacteristic *characteristic in service.characteristics) {
                if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID]]){
                    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID_WRITE]]){
                  
                }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID]]){
                    NSData *value = [_deviceIdentifier dataUsingEncoding:NSUTF8StringEncoding];
                    [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID_READ]]){
                    [peripheral readValueForCharacteristic:characteristic];
                }
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices
{
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_INFO_UUID_READ]]){
        NSData *readValue = characteristic.value;
        NSString *deviceIdentifier = [[NSString alloc] initWithData:readValue encoding:NSUTF8StringEncoding];
        
        BOOL shouldConnect = YES;
        if(!deviceIdentifier){
            shouldConnect = NO;
        }
        
        if(shouldConnect){
            @synchronized(self){
                P2PDevice  *device = _connectedDevices[deviceIdentifier];
                if(!device){
                    device = [[P2PDevice alloc] init];
                    device.identifier = deviceIdentifier;
                    _connectedDevices[deviceIdentifier] = device;
                }
                
                device.relatedPeripheral = peripheral;
                
                CBService *service = peripheral.services[0];
                NSInteger index = [service.characteristics indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                   return  [((CBCharacteristic *)obj).UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID_WRITE]];
                }];
                device.chatCharacteristicForWrite = service.characteristics[index];
                
                if(device.isReady){
                    [self handleForDeviceConnect:device isDirect:YES];
                }
                
                NSLog(@"read the identifier %@", deviceIdentifier);
                
                if(!_isCommunicationStarted){
                    [self startCommunication];
                }
            }
        }else{
            [_centralManager cancelPeripheralConnection:peripheral];
            NSLog(@"ignore peripheral: %@", peripheral.identifier.UUIDString);
        }
    }
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_CHAT_UUID]]){
        NSData *value = characteristic.value;
        [self handleReceivedPacket:value fromPeripheral:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"has written device identifier");
}


#pragma mark CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if(peripheral == _peripheralManager && _shouldAdvertiseViaPeripheral){
        NSLog(@"peripheralManager state changed to : %ld", (long)peripheral.state);
        
        if(peripheral.state == CBPeripheralManagerStatePoweredOn){
            [self startAdvertising];
        }
    }else if(peripheral == _iBeaconPeripheralManager){
        NSLog(@"iBeacon peripheralManager state changed to : %ld", (long)peripheral.state);
        
        if(peripheral.state == CBPeripheralManagerStatePoweredOn && _shouldAdvertiseViaIBeacon){
            [self startAdvertisingViaIBeacon];
        }else if(peripheral.state == CBPeripheralManagerStatePoweredOff && _shouldAdvertiseViaIBeacon){
            [self stopAdvertisingViaIBeacon];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error{
    if (error) {
        NSLog(@"fail to add service %@", error);
    }else {
        if (_shouldAdvertiseViaPeripheral) {
            [self startAdvertising];
        }
    }
}


- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if(!error){
        if(peripheral == _peripheralManager){
            NSLog(@"started advertising...");
        }else {
            NSLog(@"started ibeacon advertising...");
        }
    }else {
        NSLog(@"advertise failed with error %@", error);
    }
    
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    _existCentrals[central.identifier.UUIDString] = central;
    NSLog(@"did subscribed by central");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"did unsubscribed by central");
    @synchronized(self){
        if (_existCentrals[central.identifier.UUIDString]) {
            [_existCentrals removeObjectForKey:central.identifier.UUIDString];
        }
        
        P2PDevice *device = [self deviceForCentral:central];
        if(device){
            [_connectedDevices removeObjectForKey:device.identifier];
            
            if(device.isConnected){
                [self handleForDeviceDisconnect:device isDirect:YES];
            }
        }
    }
}



- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    if([request.characteristic.UUID isEqual:_identifierCharacteristicForRead.UUID]){
        if(request.offset <= _identifierCharacteristicForRead.value.length){
            request.value = [_identifierCharacteristicForRead.value subdataWithRange:NSMakeRange(request.offset, _identifierCharacteristicForRead.value.length - request.offset)];
            [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
        }else{
            [peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
        }
    }else{
        [peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    @synchronized(self){
        for (CBATTRequest *request in requests) {
            if([request.characteristic.UUID isEqual:_identifierCharacteristicForWrite.UUID]){
                _identifierCharacteristicForWrite.value = request.value;
                NSString *deviceidentifier = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
                
                P2PDevice *device = _connectedDevices[deviceidentifier];
                if(!device){
                    device = [[P2PDevice alloc] init];
                    device.identifier = deviceidentifier;
                    _connectedDevices[deviceidentifier] = device;
                }
                
                device.relatedCentral = request.central;
                
                if(device.isReady){
                    [self handleForDeviceConnect:device isDirect:YES];
                }
                
                NSLog(@"did write identifier %@", deviceidentifier);
            }else if([request.characteristic.UUID isEqual:_chatContentCharacteristicForWrite.UUID]){
                NSData *data = request.value;
                [self handleReceivedPacket:data fromCentral:request.central];
            }
        }
    }
}

#pragma mark CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    if(self.shouldConnectViaiBeacon && !_isCommunicationStarted){
        [self startCommunication];
    }
    
    if([region.identifier isEqualToString:self.iBeaconIdentifier]){
        //[manager startRangingBeaconsInRegion:(CLBeaconRegion *)region];
        if(self.delegate && [self.delegate respondsToSelector:@selector(P2PCommunicationCenterDidDiscoverDeviceViaIBeacon:)]){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate P2PCommunicationCenterDidDiscoverDeviceViaIBeacon:self];
            });
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{

}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
//    if(beacons.count > 0){
//        CLBeacon *beacon = beacons[0];
//        NSLog(@"proximity %ld, distance %f", (long)beacon.proximity, beacon.accuracy);
//        if(beacon.accuracy > 0 && beacon.accuracy <= 0.1f){
//            if(self.delegate && [self.delegate respondsToSelector:@selector(P2PCommunicationCenterDidDiscoverDeviceViaIBeacon:)]){
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.delegate P2PCommunicationCenterDidDiscoverDeviceViaIBeacon:self];
//                });
//            }
//            //[manager stopRangingBeaconsInRegion:region];
//        }
//        
//        if(_backgroundTaskIdentifier == UIBackgroundTaskInvalid){
//            _backgroundTaskIdentifier =  [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskIdentifier];
//            }];
//        }
//        
//    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"location  error");
}

@end
