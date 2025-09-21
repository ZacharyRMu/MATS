/*
* Code for test rotator subsystem.
* Use URTA 1 port connect to Horizontal servo(servo 0).
* Use URTA 2 port connect to vertical servo(servo 1).
* Use I2C get require angle from master device.（not tested)
* Current using code set the angle.
* For I2C we will use an Uint32_t to transfer data.
* First 16 bits will get value for horizontal angle
* Second 16 bits will get value for vertical angle
*
* Write by Minghao
* 03/18/2025
*/
#include <Wire.h>                           // Standard lib for I2C

// Standard lib for servo control
#include "FashionStar_UartServo.h"
#include "FashionStar_UartServoProtocol.h"  

#define I2C_SLV_ADDR 0x7F                   // Set I2C addr to 0x88

#define USERVO_BAUDRATE (uint32_t)115200    //serial port servo init

//serial port ajust
#define DEBUG_SERIAL Serial
#define DEBUG_SERIAL_BAUDRATE (uint32_t)115200

FSUS_Protocol protocol_ch1(&Serial1, USERVO_BAUDRATE);  //manger for port1
FSUS_Protocol protocol_ch2(&Serial2, USERVO_BAUDRATE);  //manger for port2


FSUS_Servo uservo_0(0, &protocol_ch1);  //Set Servo 0 at port 1
FSUS_Servo uservo_1(1, &protocol_ch2);  //Set Servo 1 at port 2

uint32_t recivedValue;

void onReceiveEvent(int);             //function to recive data from I2C
int getValueForHorizontal(uint32_t revicedData);  //function to get value for horizontal angle from I2C recieved value
int getValueForVerticalal(uint32_t revicedData);  //function to get value for verital angle from I2C recieved value



void setup() {
  // Put your setup code here, to run once:
  // Init servo 0
  uservo_0.init();
  // Init servo 1
  uservo_1.init(); 

  // Print message
  DEBUG_SERIAL.begin(DEBUG_SERIAL_BAUDRATE);
  DEBUG_SERIAL.println("Start To Ping Servo\n");

  // Assign one call back function(recive data from I2C)
  DEBUG_SERIAL.println("Start To Init I2c\n");
  Wire.begin(I2C_SLV_ADDR);
  Wire.onReceive(onReceiveEvent);


   // Servo 0 communication test
  bool u0_valid = uservo_0.ping(); 
  String message1 = "servo #"+String(uservo_0.servoId,DEC) + " is ";  // Log output for servo 0
  if(u0_valid){
      message1 += "online";
  }else{
      message1 += "offline";
  }    
  // init servo 0 port
  DEBUG_SERIAL.println(message1);

   // Servo 0 communication test
  bool u1_valid = uservo_1.ping(); 
  String message2 = "servo #"+String(uservo_1.servoId,DEC) + " is ";  // Log output for servo 1
  if(u1_valid){
      message2 += "online";
  }else{
      message2 += "offline";
  }    
  //init servo 1 port
  DEBUG_SERIAL.println(message2);
  delay(1000);
  Serial.println("init angle to 0. And wait 2 second");
  uservo_0.setRawAngle(0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0);  //Set servo 1 (Vertical) angle   
  delay(2000);


}

void loop() {
  // put your main code here, to run repeatedly:
  // Servo 0 communication test
  bool u0_valid = uservo_0.ping(); 
  String message1 = "servo #"+String(uservo_0.servoId,DEC) + " is ";  // Log output for servo 0
  if(u0_valid){
      message1 += "online";
  }else{
      message1 += "offline";
  }    
  // init servo 0 port
  DEBUG_SERIAL.println(message1);

   // Servo 0 communication test
  bool u1_valid = uservo_1.ping(); 
  String message2 = "servo #"+String(uservo_1.servoId,DEC) + " is ";  // Log output for servo 1
  if(u1_valid){
      message2 += "online";
  }else{
      message2 += "offline";
  }    
  //init servo 1 port
  DEBUG_SERIAL.println(message2);

  //get angle value from recived value from I2C
  int horizonAngle = getValueForHorizontal(recivedValue);
  int verticalAngle = getValueForVerticalal(recivedValue);
  String message3 = "horizonAngle:"+String(horizonAngle) + " recivedValue " + "verticalAngle:"+String(verticalAngle) + " recivedValue ";  // 日志输出
  DEBUG_SERIAL.println(message3);
  DEBUG_SERIAL.println(recivedValue);
  //Time test
  /*Serial.println("Time test");
  delay(1000);
  uservo_0.setRawAngle(-180.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(180.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 90(Azimuth) 
  Serial.println("Set 90(Azimuth) ");
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(90.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 90(Elevation Test) 
  Serial.println("Set 90(Elevation Test) ");
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(90.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 360(Command Response Test) 
  Serial.println("Set 360(Command Response Test) ");
  delay(1000);
  uservo_0.setRawAngle(-180.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(-180.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(180.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(180.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 36(Command Response Test) 
  Serial.println("Set 36(Command Response Test)");
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(36.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(36.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 72(Command Response Test) 
  Serial.println("Set 72(Command Response Test)");
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(72.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(72.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 360(Rotational Mobility Test) 
  Serial.println("Set 360(Rotational Mobility Test)");
  delay(1000);
  uservo_0.setRawAngle(-180.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(-180.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(180.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(180.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 86(Rotational Mobility Test) 
  Serial.println("Set 86(Rotational Mobility Test)");
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(36.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(36.0);  //Set servo 1 (Vertical) angle   
  delay(10000);
  //Set 172(Rotational Mobility Test)
  Serial.println("Set 172(Rotational Mobility Test)"); 
  delay(1000);
  uservo_0.setRawAngle(0.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(0.0);  //Set servo 1 (Vertical) angle
  delay(1000);
  uservo_0.setRawAngle(172.0);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(172.0);  //Set servo 1 (Vertical) angle   
  delay(10000);*/
  //I2c rotation Code(not tested)
  uservo_0.setRawAngle(horizonAngle);   //Set servo 0 (Horizontal) angle   
  uservo_1.setRawAngle(verticalAngle);  //Set servo 1 (Vertical) angle
  delay(10000);
}

/*
*function to recive data from I2C ro uint_8 recivedValue
*/
void onReceiveEvent(int) {
  while (0 < Wire.available()){
    recivedValue = Wire.read();
  }
}

/*
*function to get value for horizontal angle from I2C recieved value
*/
int getValueForHorizontal(uint32_t revicedData){
  int horizon = (int)((revicedData & 0xFFFF0000) >> 16);    //read value from upper 4 bits
  // convert angle to range from -180 to 180 degree
  int horizontalValue = horizon % 360;
  if(horizontalValue > 180){
    horizontalValue -= 360;
  }
  return horizontalValue;
}

/*
*function to get value for vertical angle from I2C recieved value
*/
int getValueForVerticalal(uint32_t revicedData){
  int vertical = (int)(revicedData & 0x0000FFFF);         //read value from last 4 bits
  // convert angle to range from 0 to 180 degree
  int verticalValue = vertical % 360;
  if(verticalValue < 0){
    return 0;
  }else if(verticalValue > 180){
    return 180;
  } else{
    return verticalValue;
  }
}