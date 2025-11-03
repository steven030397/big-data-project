# Data Dictionary

## Accident Table (`accident.csv`)

### Primary Key
- **ACCIDENT_NO** (STRING): Accident Number - Primary Key for the database to uniquely identify the accident and cannot contain NULL values.
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number

### Date and Time Fields

- **ACCIDENT_DATE** (DATE): Accident Date
  - Indicates the date that the accident occurred
  - Data is in yyyymmdd format in the database but appears in dd/mm/yyyy format in the application
  - Field can contain null values

- **ACCIDENT_TIME** (TIME): Accident Time
  - Format: hh.mm.ss
  - Original date stored in 24 hour format (i.e. 1pm = 1300 hours)
  - **Note**: Common practice used by the Police, when originally coding up the accident details, of 'rounding off the time' to the nearest 5 minutes or even nearest hour. This naturally occurs because in the vast majority of accidents police arrive at the scene well after the accident occurred and so the 'REAL' time of the accident is never precisely known.

### Accident Classification

- **ACCIDENT_TYPE** (CHAR): Accident Type
  - Basic description of what occurred, based on nine categories
  - Values: 1-9
  - Example: Collision with Vehicle

- **ACCIDENT_TYPE_DESC** (VARCHAR): Accident Type Description
  - Detailed description of accident type
  - Values:
    1. Collision with vehicle
    2. Struck pedestrian
    3. Struck animal
    4. Collision with a fixed object
    5. Collision with some other object
    6. Vehicle overturned (no collision)
    7. Fall from or in moving vehicle
    8. No collision and no object struck
    9. Other accident

### Day of Week

- **DAY_OF_WEEK** (INTEGER): Day of Week
  - Indicates the day of the week upon which the accident occurred
  - Values: 1-7

- **DAY_WEEK_DESC** (NVARCHAR): Day of Week Description
  - Values:
    1. Sunday
    2. Monday
    3. Tuesday
    4. Wednesday
    5. Thursday
    6. Friday
    7. Saturday

### DCA (Definitions for Classifying Accidents)

- **DCA_CODE** (CHAR): DCA Code
  - Definitions for Classifying Accidents
  - Cannot contain NULL values
  - Values: 100-781

- **DCA_DESC** (VARCHAR): DCA Description
  - Description for the Accident Classification
  - Comprehensive classification system including:
    - **100-109**: Pedestrian accidents
      - 100: Pedestrian near side hit by vehicle from the right
      - 101: Pedestrian emerges from in front of parked or stationary vehicle
      - 102: Pedestrian far side hit by vehicle from the left
      - 103: Pedestrian playing, lying, working, standing on carriageway
      - 104: Pedestrian walking with traffic
      - 105: Pedestrian walking against traffic
      - 106: Vehicle strikes pedestrian on footpath, median, traffic island
      - 107: Pedestrian on footpath struck by vehicle entering/leaving driveway
      - 108: Pedestrian struck walking to/from or boarding/alighting vehicle
      - 109: Any manoeuvre involving Pedestrian not included in DCAs 100-108
    
    - **110-119**: Intersection accidents
      - 110: Cross traffic (intersections only)
      - 111: Right far (intersections only)
      - 112: Left far (intersections only)
      - 113: Right near (intersections only)
      - 114: Two right turning (intersections only)
      - 115: Right/left far (intersections only)
      - 116: Left near (intersections only)
      - 117: Left/right far (intersections only)
      - 118: Two left turning (intersections only)
      - 119: Other adjacent (intersections only)
    
    - **120-129**: Opposing vehicle accidents
      - 120: Head on (not overtaking)
      - 121: Right through
      - 122: Left through
      - 123: Right/left (one vehicle turning right the other left)
      - 124: Right/right (both vehicles from opposite directions turning right)
      - 125: Left/left (both vehicles from opposite directions turning right)
      - 129: Other opposing (manoeuvres not included in DCAs 120-125)
    
    - **130-139**: Same direction accidents
      - 130: Rear end (vehicles in same lane)
      - 131: Left rear
      - 132: Right rear
      - 133: Lane side swipe (vehicles in parallel lanes)
      - 134: Lane change right (not overtaking)
      - 135: Lane change left (not overtaking)
      - 136: Right turn sideswipe
      - 137: Left turn sideswipe
      - 139: Other same direction (manoeuvres not included in DCAs 130-137)
    
    - **140-149**: Parking and reversing accidents
      - 140: U turn
      - 141: U turn into fixed object/parked vehicle
      - 142: Leaving parking
      - 143: Entering parking
      - 144: Parked vehicles only
      - 145: Reversing in stream of traffic
      - 146: Reversing into fixed object/parked vehicle
      - 147: Vehicle strikes another vehicle while emerging from driveway
      - 148: Vehicle off footpath strikes vehicle on carriageway
      - 149: Other (manoeuvres not included in DCAs 140-148)
    
    - **150-159**: Overtaking accidents
      - 150: Head on (overtaking)
      - 151: Out of control (overtaking)
      - 152: Pulling out (overtaking)
      - 153: Cutting in (overtaking)
      - 154: Pulling out rear end
      - 159: Other overtaking (manoeuvres not included in DCAs 150-154)
    
    - **160-169**: Object/parked vehicle accidents
      - 160: Vehicle collides with vehicle parked on left of road
      - 161: Double parked
      - 162: Accident or broken down
      - 163: Vehicle strikes door of parked/stationary vehicle
      - 164: Permanent obstruction on carriageway
      - 165: Temporary roadworks
      - 166: Struck object on carriageway
      - 167: Struck animal
      - 169: Other on path
    
    - **170-179**: Off carriageway straight
      - 170: Off carriageway to left
      - 171: Left off carriageway into object/parked vehicle
      - 172: Off carriageway to right
      - 173: Right off carriageway into object/parked vehicle
      - 174: Out of control on carriageway (on straight)
      - 175: Off end of road/T intersection
      - 179: Other accidents off straight not included in DCAs 170-175
    
    - **180-189**: Off carriageway on bend
      - 180: Off carriageway on right bend
      - 181: Off right bend into object/parked vehicle
      - 182: Off carriageway on left bend
      - 183: Off left bend into object/parked vehicle
      - 184: Out of control on carriageway (on bend)
      - 189: Other accidents on curve not included in DCAs 180-184
    
    - **190-199**: Other accidents
      - 190: Fell in/from vehicle
      - 191: Load or missile struck vehicle
      - 192: Struck train
      - 193: Struck railway crossing furniture
      - 194: Parked car run away
      - 198: Other accidents not classifiable elsewhere
      - 199: Unknown no details on manoeuvres of road users in accident
    
    - **Group codes (770-781)**:
      - 775: RUN OFF ROAD + SOME HEAD ONS
      - 777: SPEEDING DCA GROUP FOR POLICE
      - 778: Pedestrian DCAs
      - 779: Cross - Rears Cross traffic rear ends
      - 780: Run Off Road DCAs 170-184
      - 781: R Taylor (TAC)

### Environmental Conditions

- **LIGHT_CONDITION** (CHAR): Light Condition
  - Indicates the light condition or level of brightness at the time of the accident
  - Cannot contain NULL values
  - Values: 1-9
    - 1: Day
    - 2: Dusk/dawn
    - 3: Dark street lights on
    - 4: Dark street lights off
    - 5: Dark no street lights
    - 6: Dark street lights unknown
    - 9: Unknown

### Location and Road Characteristics

- **NODE_ID** (INTEGER): Node ID
  - The node id of the accident
  - Starts at 1 and incremented by one when a new accident location is identified

- **ROAD_GEOMETRY** (CHAR): Road Geometry
  - Code for layout of the road where the accident occurred
  - Values: 1-9

- **ROAD_GEOMETRY_DESC** (VARCHAR): Road Geometry Description
  - Descriptions of the layout of the road where the accident occurred
  - Values:
    1. Cross intersection
    2. 'T' Intersection
    3. 'Y' Intersection
    4. Multiple intersections
    5. Not at intersection
    6. Dead end
    7. Road closure
    8. Private property
    9. Unknown

- **SPEED_ZONE** (CHAR): Speed Zone
  - The speed zone at the location of the accident
  - The speed zone is generally assigned to the main vehicle involved
  - Values:
    - 040: 40 km/hr
    - 050: 50 km/hr
    - 060: 60 km/hr
    - 075: 75 km/hr
    - 080: 80 km/hr
    - 090: 90 km/hr
    - 100: 100 km/hr
    - 110: 110 km/hr
    - 777: Other speed limit
    - 888: Camping grounds, off road
    - 999: Not known

### Vehicle and Person Counts

- **NO_OF_VEHICLES** (INTEGER): Number of Vehicles involved
  - The number of vehicles involved in the accident
  - Includes bicycles but not objects, property, toys (skate boards), etc.

- **NO_PERSONS** (INTEGER): Number of Persons
  - Indicates the number of people involved in the accident
  - NULL values are valid entries

- **NO_PERSONS_KILLED** (INTEGER): Number of Lives lost
  - Number of people who have died in the crash

- **NO_PERSONS_INJ_2** (INTEGER): Number of Person/s with Serious Injury
  - Number of people with a serious injury

- **NO_PERSONS_INJ_3** (INTEGER): Number of Person/s with other injury
  - Number of people with an other injury

- **NO_PERSONS_NOT_INJ** (INTEGER): Number of Person/s not injury
  - Number of people with no injuries

### Severity

- **SEVERITY** (CHAR): Severity
  - Estimation of the severity or seriousness of the accident
  - Values:
    1. Fatal accident
    2. Serious injury accident
    3. Other injury accident
    4. Non injury accident

### Police Information

- **POLICE_ATTEND** (CHAR): Police attendance
  - Indicates whether the police attended the scene of the accident or not
  - Cannot contain NULL values
  - Values:
    - 1: Yes
    - 2: No
    - 9: Not known

---

## Vehicle Table (`vehicle.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **VEHICLE_ID** (CHAR): Vehicle ID
  - Character field that uniquely identifies each vehicle involved in the accident
  - Vehicles have a letter value assigned to them
  - Cannot contain NULL values

### Vehicle Identification and Characteristics

- **VEHICLE_YEAR_MANUF** (INTEGER): Vehicle Year of Manufacture
  - Integer field indicates the year in which the vehicle was built or manufactured
  - Data is stored in yyyy format

### Vehicle Movement and Direction

- **VEHICLE_DCA_CODE** (CHAR): Vehicle DCA Code
  - Character field indicates that links the vehicle with the movement depicted in the DCA table
  - For example, if the DCA code for the accident is 111 and the vehicle DCA code is 2, then an inspection of the DCA chart will show that the second vehicle involved in the accident was turning right
  - Values:
    1. Vehicle 1
    2. Vehicle 2
    3. Not known which vehicle was number 1
    8. Not involved in initial event

- **INITIAL_DIRECTION** (CHAR): Initial Direction
  - Indicates the initial or first direction of travel of the vehicle
  - For a vehicle that is turning, the initial direction will be different to the final direction
  - For a non-turning vehicle, the initial direction will be the same as the final direction
  - Values:
    - E: East
    - N: North
    - NE: North east
    - NW: North west
    - S: South
    - SE: South east
    - SW: South west
    - W: West
    - NK: Not known

- **FINAL_DIRECTION** (CHAR): Final Direction
  - Indicates the final or last direction of travel of the vehicle
  - For a vehicle that is turning, the initial direction will be different to the final direction
  - For a non-turning vehicle, the initial direction will be the same as the final direction
  - Values: E, N, NE, NW, S, SE, SW, W, NK (Not known)

- **DRIVER_INTENT** (CHAR): Driver Intent
  - Indicates what the driver of the vehicle was attempting to undertake at the time of the accident
  - This information is meant to obtain via an interview of the vehicle's driver
  - Values:
    01. Going straight ahead
    02. Turning right
    03. Turning left
    04. Leaving a driveway
    05. 'U' turning
    06. Changing lanes
    07. Overtaking
    08. Merging
    09. Reversing
    10. Parking or unparking
    11. Parked legally
    12. Parked illegally
    13. Stationary accident
    14. Stationary broken down
    15. Other stationary
    16. Avoiding animals
    17. Slow/stopping
    18. Out of control
    19. Wrong way
    99. Not known

- **VEHICLE_MOVEMENT** (CHAR): Vehicle Movement
  - Indicates the actual movement of the vehicle prior to the accident
  - Values: Same as DRIVER_INTENT (01-19, 99), plus "_" (Blank value entered)

### Road Surface

- **ROAD_SURFACE_TYPE** (CHAR): Road Surface Type
  - Describes the type of road surface the crash occurred on (e.g. paved, unpaved, gravel etc)
  - Values:
    1. Paved
    2. Unpaved
    3. Gravel
    9. Not known

- **ROAD_SURFACE_TYPE_DESC** (VARCHAR): Road Surface Type Description
  - Descriptive field that describes the type of road surface the crash occurred on
  - Values: Same as ROAD_SURFACE_TYPE

### Vehicle Registration

- **REG_STATE** (CHAR): Registration State
  - Indicates the state which the vehicle is registered in
  - Will also indicate if the registration is overseas
  - Cannot contain NULL values
  - Values:
    - A: Australian Capital Territory
    - B: Commonwealth
    - D: Northern Territory
    - N: New South Wales
    - O: Overseas
    - Q: Queensland
    - S: South Australia
    - T: Tasmania
    - V: Victoria
    - W: Western Australia
    - Z: Not known
    - _ (Blank value entered)/Not available

### Vehicle Type and Body Style

- **VEHICLE_TYPE** (CHAR): Vehicle Type
  - Indicates the type or category of vehicle
  - Cannot contain NULL values
  - Values:
    01. Car
    02. Station wagon
    03. Taxi
    04. Utility
    05. Panel van
    06. Prime Mover (No of Trailers Unknown)
    07. Rigid Truck (Weight Unknown)
    08. Bus/coach
    09. Mini bus (9-13) seats
    10. Motor cycle
    11. Moped
    12. Motor scooter
    13. Bicycle
    14. Horse (ridden or drawn)
    15. Tram
    16. Train
    17. Other vehicle
    18. Not Applicable
    19. Parked Trailers
    20. Quad Bike
    27. Plant machinery and Agricultural equipment
    60. Prime Mover Only
    61. Prime Mover – Single Trailer
    62. Prime Mover – B-Double
    63. Prime Mover B-Triple
    71. Light Commercial Vehicle (Rigid) <= 4.5 Tonnes GVM
    72. Heavy Vehicle (Rigid) > 4.5 Tonnes
    99. Not known

- **VEHICLE_TYPE_DESC** (VARCHAR): Vehicle Type Description
  - Descriptive field that indicates the type or category of vehicle
  - Cannot contain NULL values
  - Values: Same as VEHICLE_TYPE

- **VEHICLE_BODY_STYLE** (CHAR): Vehicle Body Style
  - Indicates the body type of the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - This match is based on the registration number with confirmation of the date of expiry and the owner's name
  - Cannot contain NULL values
  - **Note**: This field has an extensive list of body style codes (e.g., AFRAME, BUS, CAR, SEDAN, etc.). The quality depends on successful VRIS database matching.

### Vehicle Specifications

- **VEHICLE_MAKE** (CHAR): Vehicle Make
  - Indicates the vehicle make or manufacturer
  - Cannot contain NULL values
  - **Note**: Extensive list of vehicle makes (e.g., FORD, TOYOTA, HOLDEN, MAZDA, etc.)

- **VEHICLE_MODEL** (CHAR): Vehicle Model
  - Indicates the model of the vehicle
  - Examples: FALCON, 0 (Unknown), 66 (Sleeper), 75 (Tow)

- **VEHICLE_YEAR_MANUF** (INTEGER): Vehicle Year of Manufacture
  - Indicates the year in which the vehicle was built or manufactured
  - Data stored in yyyy format

- **VEHICLE_POWER** (INTEGER): Vehicle Power
  - Indicates the power of the vehicle, in CCs or horsepower
  - For motor cycles, motor scooters and mopeds, the units will be CCs
  - For all other vehicles, the units are rated horsepower
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - Values:
    - 0: Unknown
    - 1-1000: Horsepower
    - 1-9999: CCs

- **VEHICLE_WEIGHT** (INTEGER): Vehicle Weight
  - Indicates the weight or mass of the vehicle
  - The unit of measurement is kilograms
  - NULL values are valid entries

- **NO_OF_WHEELS** (INTEGER): Number of Wheels
  - Indicates the number of wheels that the vehicle has
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - NULL values are valid entries

- **NO_OF_CYLINDERS** (INTEGER): Number of Cylinders
  - Indicates the number of engine cylinders that the vehicle has
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - NULL values are valid entries

- **SEATING_CAPACITY** (INTEGER): Seating Capacity
  - Indicates the number of seats in the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - NULL values are valid entries

- **TARE_WEIGHT** (INTEGER): Tare Weight
  - Indicates the tare or unladen weight of the vehicle
  - The unit of measurement is kilograms
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - NULL values are valid entries

- **CARRY_CAPACITY** (INTEGER): Carry Capacity
  - Indicates the carry or load capacity of the vehicle
  - The unit of measurement is kilograms
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - NULL values are valid entries

- **CUBIC_CAPACITY** (INTEGER): Cubic Capacity
  - Indicates the cubic capacity of the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - This field cannot contain NULL values

### Vehicle Occupancy

- **TOTAL_NO_OCCUPANTS** (INTEGER): Total Number of Occupants
  - Indicates the number of occupants or people in the vehicle at the time of the accident
  - NULL values are valid entries

### Vehicle Construction and Fuel

- **CONSTRUCTION_TYPE** (CHAR): Construction Type
  - Indicates the construction or formation of the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - This match is based on the registration number with confirmation of the date of expiry and the owner's name
  - Cannot contain NULL values
  - Values:
    - A: Articulated
    - P: Interpretation is not known
    - R: Rigid
    - _ (Blank value entered): Unknown

- **FUEL_TYPE** (CHAR): Fuel Type
  - Indicates the type of fuel used by the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - Cannot contain NULL values
  - Values:
    - D: Diesel
    - E: Electric
    - G: Gas
    - M: Multi
    - P: Petrol
    - R: Rotary
    - Z: Unknown

### Vehicle Appearance

- **VEHICLE_COLOUR_1** (CHAR): Vehicle Colour 1 (Primary)
  - Indicates the primary or main colour of the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - Values:
    - BLK: Black
    - BLU: Blue
    - BRN: Brown
    - CRM: Cream
    - FWN: Fawn
    - GLD: Gold
    - GRN: Green
    - GRY: Grey
    - MRN: Maroon
    - MVE: Mauve
    - OGE: Orange
    - PNK: Pink
    - PUR: Purple
    - RED: Red
    - SIL: Silver
    - WHI: White
    - YLW: Yellow
    - ZZ: Unknown or Not applicable

- **VEHICLE_COLOUR_2** (CHAR): Vehicle Colour 2 (Secondary)
  - Indicates the secondary colour of the vehicle
  - The quality of the data is dependent on a successful match between the accident and vehicle (VRIS) databases
  - Valid entries are same as VEHICLE_COLOUR_1

### Vehicle Damage and Impact

- **INITIAL_IMPACT** (CHAR): Initial Impact
  - Indicates the position on the vehicle where the initial impact occurred
  - Values:
    - 0: Towed unit
    - 1: Right front corner
    - 2: Right side forwards
    - 3: Right side rearwards
    - 4: Right rear corner
    - 5: Left front corner
    - 6: Left side forwards
    - 7: Left side rearwards
    - 8: Left rear corner
    - 9: Not known/not applicable
    - F: Front
    - N: None
    - R: Rear
    - S: Sidecar
    - T: Top/roof
    - U: Undercarriage
    - _ (Blank value entered)

- **LEVEL_OF_DAMAGE** (CHAR): Level of Damage
  - Indicates the damage level of the vehicle
  - Values:
    1. Minor
    2. Moderate (driveable vehicle)
    3. Moderate (unit towed away)
    4. Major (unit towed away)
    5. Extensive (unrepairable)
    6. Nil damage
    9. Not known

- **CAUGHT_FIRE** (CHAR): Caught Fire
  - Indicates whether or not the vehicle caught fire as a result of the accident
  - Values:
    - 0: Not applicable
    - 1: Yes
    - 2: No
    - 9: Not known

- **TOWED_AWAY_FLAG** (CHAR): Towed Away Flag
  - Indicates whether or not the vehicle was towed from the accident site
  - Values: 1, 2

### Vehicle Lighting

- **LAMPS** (CHAR): Lamps
  - Indicates whether the lamps or headlights for the vehicle (under the ambient lighting conditions) were alight (on)
  - Values:
    - 0: Not applicable
    - 1: Yes
    - 2: No
    - 9: Not known

### Trailer Information

- **TRAILER_TYPE** (CHAR): Trailer Type
  - Indicates the type of trailer towed by the vehicle involved in the accident, as reported by the police
  - Values:
    - A: Caravan
    - B: Trailer (general)
    - C: Trailer (boat)
    - D: Horse float
    - E: Machinery
    - F: Farm/agricultural equipment
    - G: Not known what is being towed
    - H: Not applicable
    - I: Trailer (Exempt)
    - J: Semi Trailer
    - K: Pig Trailer
    - L: Dog Trailer

### Traffic Control

- **TRAFFIC_CONTROL** (CHAR): Traffic Control
  - Indicates the traffic control facing that was facing the vehicle, prior to the accident

- **TRAFFIC_CONTROL_DESC** (VARCHAR): Traffic Control Description
  - Descriptive field that indicates the traffic control facing that was facing the vehicle, prior to the accident

---

## Notes

### General Notes
- The DCA (Definitions for Classifying Accidents) system provides a comprehensive classification scheme for different types of accidents
- Time accuracy may be limited due to police arriving after the accident occurred
- Several fields can contain NULL values, which should be handled appropriately in analysis
- The speed zone field uses specific codes, including special codes for "other" (777), "camping grounds/off road" (888), and "not known" (999)

### Vehicle Table Specific Notes
- Many vehicle specification fields (body style, make, power, weight, etc.) depend on successful matching between the accident database and the VRIS (Vehicle Registration Information System) database
- The VRIS match is based on the registration number with confirmation of the date of expiry and the owner's name
- When VRIS matching fails, these fields may contain NULL values or default/unknown codes
- Vehicle DCA code links each vehicle to its specific movement/role in the accident as described in the DCA table
- Initial and final directions help track vehicle movement through turns and maneuvers

---

## Sub DCA Table (`sub_dca.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **SUB_DCA_SEQ** (INTEGER): Sub DCA Sequence
  - Starts with 1 and incremented by 1 if more than one Sub DCA is entered for the same incident
  - Links to DCA Chart and Sub DCA Codes

### Sub DCA Classification

- **SUB_DCA_CODE** (CHAR): Sub DCA Code
  - Character field indicates the SUB_DCA code of the accident
  - Cannot contain NULL values
  - Provides detailed classification beyond the main DCA code
  - **Note**: This field has an extensive list of sub-classification codes (see SUB_DCA_CODE_DESC for full list)

- **SUB_DCA_CODE_DESC** (VARCHAR): Sub DCA Code Description
  - Descriptive field that indicates the SUB_DCA code of the accident
  - Cannot contain NULL values
  - Provides detailed descriptions for sub-classifications

### Sub DCA Code Categories

The Sub DCA codes are organized into categories with letter prefixes:

- **A - Vehicle at Intersection**:
  - A01: Vehicle entering intersection
  - A02: Vehicle leaving intersection
  - A03: Vehicle within intersection
  - A04: Vehicle in left turn slip lane

- **B - Vehicle Movement**:
  - B01: Vehicle going straight through
  - B02: Vehicle turning right
  - B03: Vehicle turning left
  - B04: Vehicle reversing

- **C - Pedestrian Stepping Off**:
  - C01: Pedestrian stepped off median strip
  - C02: Pedestrian stepped off safety zone/tram shelter

- **D - Pedestrian Emerging from Behind Vehicle**:
  - D01: Pedestrian emerged from behind car etc
  - D02: Pedestrian emerged from behind truck
  - D03: Pedestrian emerged from behind bus
  - D04: Pedestrian emerged from behind tram
  - D05: Pedestrian emerged from behind motorcycle
  - D06: Pedestrian emerged from behind other vehicles
  - D07: Pedestrian emerged from behind vehicle not known

- **E - Pedestrian Activity**:
  - E01: Pedestrian playing
  - E02: Pedestrian walking
  - E03: Pedestrian lying
  - E04: Pedestrian standing
  - E05: Pedestrian working/pushing or working on vehicle
  - E06: Pedestrian activity not known

- **F - Footpath**:
  - F01: No paved footpath
  - F02: Paved footpath
  - F03: Footpath unknown
  - F04: Not on Footpath

- **G - Vehicle Control**:
  - G01: Vehicle moving forward - under control
  - G02: Vehicle moving forward - out of control
  - G03: Vehicle moving back - under control
  - G04: Vehicle moving back - out of control

- **H - Vehicle Driveway Movement**:
  - H01: Vehicle forward entering
  - H02: Vehicle reverse entering
  - H03: Vehicle forward departing
  - H04: Vehicle reverse departing

- **I - Driveway/Laneway Type**:
  - I01: Private driveway/laneway
  - I02: Hotel/motel/hostel driveway or laneway
  - I03: Factory(including loading bays) driveway/laneway
  - I04: Commercial(includes shops/school/station) driveway
  - I05: Not known
  - I06: Laneway

- **J - Vehicle Boarding**:
  - J01: Boarding
  - J02: Alighting

- **K - Separator**:
  - K01: Median
  - K02: Other separator

- **L - Road Configuration**:
  - L01: Road straight at intersection
  - L02: Road curved at intersection
  - L03: Road straight at mid-block
  - L04: Road curved at mid-block

- **M - Median Opening**:
  - M01: Vehicle turning through median opening

- **N - Location Type**:
  - N01: Intersection
  - N02: Mid-block
  - NRQ: Not Required

- **O - Parked Vehicle Influence**:
  - O01: Parked vehicle causes vehicle to change lanes

- **P - U-turn Collision**:
  - P01: Hit by veh from same dir as initial dir of U-turning veh
  - P02: Hit by veh fr dir opposite to initial dir of U-turning veh

- **Q - Objects Hit**:
  - Q01: Poles (telephone/electricity)
  - Q02: Tree (shrub/scrub)
  - Q03: Fences (including gates)
  - Q04: Embankments
  - Q05: Guide posts (including km/posts)
  - Q06: Traffic signs (No parking No standing etc)
  - Q07: Guard rail
  - Q08: Fire hydrant
  - Q09: Buildings
  - Q10: Other objects (Telephone/Culvert/RX) Fixed/Not Fixed
  - Q11: Object hit not known
  - Q12: Traffic signals(i.e.Traffic lights)
  - Q13: Bridge(When it is NOT on path)
  - Q14: Barriers (Road Closure)
  - Q17: Traffic island
  - Q21: Bridge (When it is ON path - see 1)
  - Q23: Roadworks (Dirt sign/barrier/excavation)
  - Q24: Safety zone (i.e. Tram safety zone)
  - Q30: Protruding kerb
  - Q31: Animals - Domestic (Cats and Dogs)
  - Q32: Animals - Cattle
  - Q33: Animals - Sheep
  - Q34: Animals - Horse (not ridden)
  - Q35: Animals - Other tame animals
  - Q36: Animals - Kangaroo or Wallaby
  - Q37: Animals - Wombat
  - Q38: Animals - Other wild animal or bird
  - Q39: Unknown animals

- **R - Parking Configuration**:
  - R01: Kerb parking - angle
  - R02: Kerb parking - parallel
  - R03: Centre of road parking - angle
  - R04: Centre of road parking - parallel
  - R05: Parking offroad/footpath

- **S - Collision Location**:
  - S01: Collision on first half of carriageway
  - S02: Collision on second half of carriageway
  - S03: On footpath

- **U - Opposing Vehicle**:
  - U01: Opposing direction vehicle present

- **V - Mounting/Striking**:
  - V01: No vehicle mounted/struck
  - V02: Kerb(roadside) mounted/struck
  - V03: Traffic island mounted/struck
  - V04: Safety zone mounted/struck
  - V05: Median mounted/struck
  - V06: Separation mounted/struck
  - V07: Roundabout mounted/struck

- **W - Carriageway Departure**:
  - W01: Leaves carriageway to left
  - W02: Leaves carriageway to right

- **X - Fall**:
  - X01: Fell in vehicle
  - X02: Fell from vehicle

- **Y - Vehicle Collision**:
  - Y01: Any vehicle (include trailer or parked car)

- **Z - Freeway/Ramp**:
  - Z01: On freeway (between interchanges)
  - Z02: At entrance ramp/local road intersection
  - Z03: On entrance ramp
  - Z04: At entrance ramp/freeway
  - Z05: At freeway/exit ramp (vehicle about to leave freeway)
  - Z06: On exit ramp
  - Z07: At exit ramp/local road intersection
  - Z08: Freeway/freeway interchange
  - Z09: At local rd I/S or M/B with RRP/RS spanning part of freeway

---

## Person Table (`person.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **PERSON_ID** (CHAR): Person ID
  - Uniquely identifies each person involved in the accident
  - Persons who are drivers of a vehicle have a letter value assigned to them
  - Persons who are not drivers have a numerical value assigned to them

### Person Identification

- **VEHICLE_ID** (CHAR): Vehicle ID
  - Character field that uniquely identifies each vehicle involved in the accident
  - Vehicles have a letter value assigned to them
  - Links the person to their associated vehicle (if applicable)

- **SEX** (CHAR): Sex
  - Indicates the person's sex
  - This is a user editable field
  - Values:
    - M: Male
    - F: Female
    - U: Not known

- **AGE_GROUP** (VARCHAR): Age Group
  - The age grouping of the person involved in the crash

### Injury Information

- **INJ_LEVEL** (CHAR): Injury Level
  - Indicates the level or degree of injury that the person has experienced as a result of the accident
  - This is a calculated field using `inj_police_level` and `taken_hospital`
  - Cannot contain NULL values
  - Values:
    1. Fatality
    2. Serious injury
    3. Other injury
    4. Not injured

- **INJ_LEVEL_DESC** (VARCHAR): Injury Level Description
  - Descriptive field that indicates the level or degree of injury that the person has experienced as a result of the accident
  - Values: Same as INJ_LEVEL

- **TAKEN_HOSPITAL** (CHAR): Taken to Hospital
  - Indicates whether or not the person was taken to hospital
  - Cannot contain NULL values
  - Values:
    - Y: Yes
    - N: No
    - _: Not Known

- **EJECTED_CODE** (CHAR): Ejected Code
  - Indicates whether or not the person was ejected or thrown out of the vehicle
  - Cannot contain NULL values
  - Values:
    - 0: Not applicable
    - 1: Total ejected
    - 2: Partially ejected
    - 3: Partial ejection involving extraction
    - _: Not known

### Vehicle Occupancy

- **SEATING_POSITION** (CHAR): Seating Position
  - Indicates where the person was located in the vehicle
  - Cannot contain NULL values
  - Values:
    - CF: Centre-front
    - CR: Centre-rear
    - D: Driver or rider
    - LF: Left-front
    - LR: Left-rear
    - NA: Not applicable
    - NK: Not known
    - OR: Other-rear
    - PL: Pillion passenger
    - PS: Motorcycle sidecar passenger
    - RR: Right-rear

- **HELMET_BELT_WORN** (CHAR): Seat Belt/Helmet Worn
  - Indicates whether or not the person was wearing a helmet or seatbelt at the time of the accident
  - Cannot contain NULL values
  - Values:
    1. Seatbelt worn
    2. Seatbelt not worn
    3. Child restraint worn
    4. Child restraint not worn
    5. Seatbelt/restraint not fitted
    6. Crash helmet worn
    7. Crash helmet not worn
    8. Not appropriate
    9. Not known

### Person Role

- **ROAD_USER_TYPE** (CHAR): Road User Type
  - Indicates what the role of the person was at the time of the accident
  - This is a calculated field using `person_status` and `vehicle_type` from vehicle table
  - Cannot contain NULL values
  - Values:
    1. Pedestrian
    2. Driver (of V-type 1-9, 17, 60-63, 70-71)
    3. Passenger (of V-type 1-9, 17, 60-63, 70-71)
    4. Motorcyclist
    5. Pillion Passenger
    6. Bicyclist (incl. passengers)
    7. Other driver (V-type 14-16, 99)
    8. Other passenger (V-type 14-16, 99)
    9. Not known

- **ROAD_USER_TYPE_DESC** (VARCHAR): Road User Type Description
  - Descriptive field that indicates what the role of the person was at the time of the accident
  - This is a calculated field using `person_status` and `vehicle_type` from vehicle table
  - Values: Same as ROAD_USER_TYPE

### License Information

- **LICENCE_STATE** (CHAR): Licence State
  - Indicates the state of issue of the person's driver license
  - Cannot contain NULL values
  - Values:
    - A: Australian Capital Territory
    - B: Commonwealth
    - D: Northern Territory
    - N: New South Wales
    - O: Overseas
    - Q: Queensland
    - S: South Australia
    - T: Tasmania
    - V: Victoria
    - W: Western Australia
    - Z: Not known
    - _: Not available (Blank value entered)

---

## Notes

### General Notes
- The DCA (Definitions for Classifying Accidents) system provides a comprehensive classification scheme for different types of accidents
- Time accuracy may be limited due to police arriving after the accident occurred
- Several fields can contain NULL values, which should be handled appropriately in analysis
- The speed zone field uses specific codes, including special codes for "other" (777), "camping grounds/off road" (888), and "not known" (999)

### Vehicle Table Specific Notes
- Many vehicle specification fields (body style, make, power, weight, etc.) depend on successful matching between the accident database and the VRIS (Vehicle Registration Information System) database
- The VRIS match is based on the registration number with confirmation of the date of expiry and the owner's name
- When VRIS matching fails, these fields may contain NULL values or default/unknown codes
- Vehicle DCA code links each vehicle to its specific movement/role in the accident as described in the DCA table
- Initial and final directions help track vehicle movement through turns and maneuvers

### Sub DCA Table Specific Notes
- Sub DCA codes provide detailed classification beyond the main DCA code
- Multiple Sub DCA codes can be associated with a single accident (indicated by SUB_DCA_SEQ)
- Sub DCA codes are organized into categories (A-Z) covering various aspects of the accident scenario
- These codes provide granular detail about pedestrian activity, vehicle movement, road conditions, objects hit, and other specific circumstances

### Person Table Specific Notes
- PERSON_ID uniquely identifies each person; drivers are assigned letters, non-drivers are assigned numbers
- Injury level is calculated from police injury level and hospital admission status
- Road user type is calculated from person status and vehicle type
- Seating position is only applicable for vehicle occupants; pedestrians and cyclists will have "Not applicable"
- The relationship between persons and vehicles is established through VEHICLE_ID
- Ejection status is only relevant for vehicle occupants

---

## Node Table (`node.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **NODE_ID** (INTEGER): Node ID
  - The node id of the accident
  - Starts at 1 and incremented by one when a new accident location is identified

### Location Classification

- **NODE_TYPE** (NVARCHAR): Node Type
  - Indicates location type identified by the RCIS (Road Crash Information System) spatial system
  - Cannot contain NULL values
  - Values:
    - I: Intersection
    - N: Non-Intersection
    - O: Off Road
    - U: Unknown

### Spatial Coordinates

- **AMG_X** (NUMERIC): AMG X Coordinate
  - Decimal field that contains AMG (Australian Map Grid) coordinate X value
  - Cannot contain NULL values
  - Will have zero value for location unknown accidents

- **AMG_Y** (NUMERIC): AMG Y Coordinate
  - Decimal field that contains AMG (Australian Map Grid) coordinate Y value
  - Cannot contain NULL values
  - Will have zero value for location unknown accidents

- **LATITUDE** (DECIMAL): Latitude
  - Latitude coordinate of the crash

- **LONGITUDE** (DECIMAL): Longitude
  - Longitude coordinate of the crash

### Geographic Information

- **LGA_NAME** (NVARCHAR): LGA (Local Government Area)
  - Character field contains the LGA name for the location of the crash
  - Cannot contain NULL values

- **DEG_URBAN_NAME** (NVARCHAR): Degree Urban Name
  - Character field indicates degree of urban name for the location of the crash
  - This field refers to DEG_URBAN_NAME in DEGREE_OF_URBAN table
  - Cannot contain NULL values
  - **Note**: Used in analysis to classify crashes as Urban or Rural (e.g., "MEL", "LAR", "SMA", "MED", "REG", "RUR")

- **POSTCODE_CRASH** (INTEGER): Postcode Crash
  - Postcode of the crash location

---

## Atmospheric Condition Table (`atmospheric_cond.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **ATMOSPH_COND_SEQ** (INTEGER): Atmospheric Condition Sequence
  - Starts with 1 and incremented by 1 if more than one atmospheric condition is entered for the same incident

### Atmospheric Conditions

- **ATMOSPH_COND** (CHAR): Atmospheric Condition
  - Weather and atmospheric conditions at the time of the crash
  - Values:
    1. Clear
    2. Raining
    3. Snowing
    4. Fog
    5. Smoke
    6. Dust
    7. Strong winds
    9. Not known

- **ATMOSPH_COND_DESC** (VARCHAR): Atmospheric Condition Description
  - Descriptive field for atmospheric conditions
  - Values: Same as ATMOSPH_COND (Clear, Raining, Snowing, Fog, Smoke, Dust, Strong winds, Not known)

---

## Accident Event Table (`accident_event.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **EVENT_SEQ_NO** (INTEGER): Sequence
  - Integer field that starts with 1 and incremented for more than one event in the same accident
  - Cannot contain NULL values

### Event Classification

- **EVENT_TYPE** (CHAR): Event Type
  - Character field indicates type of incident event
  - Cannot contain NULL values
  - Values:
    - 0: Not applicable
    - 1: Rollover on/off carriageway
    - 2: Fell from vehicle
    - 3: Ran off carriageway
    - 4: Mechanical failure
    - 5: Struck by stone/projectile/load
    - 6: Fell in vehicle
    - 8: Other
    - 9: Not known
    - C: Collision

- **EVENT_TYPE_DESC** (VARCHAR): Event Type Description
  - Descriptive field that indicates type of incident event
  - Cannot contain NULL values
  - Values: Same as EVENT_TYPE

### Vehicle Participants

- **VEHICLE_1_ID** (CHAR): First Participant Vehicle ID
  - Character field indicates first vehicle involved in the event
  - Vehicle ID has a letter value assigned to them
  - Cannot contain NULL values

- **VEHICLE_1_COLL_PT** (CHAR): Point of Collision 1
  - Character field indicates collision point on the first vehicle
  - Cannot contain NULL values

- **VEHICLE_1_COLL_PT_DESC** (VARCHAR): Vehicle 1 Collision Point Description
  - Descriptive field that indicates collision point on the first vehicle
  - Cannot contain NULL values
  - Values:
    - 0: Towed unit
    - 1: Right front corner
    - 2: Right side (forwards)
    - 3: Right side (rearwards)
    - 4: Right rear corner
    - 5: Left front corner
    - 6: Left side (forwards)
    - 7: Left side (rearwards)
    - 8: Left rear corner
    - 9: Not known or Not Applicable
    - F: Front
    - N: None
    - R: Rear
    - S: Sidecar
    - T: Top/Roof
    - U: Undercarriage

- **VEHICLE_2_ID** (CHAR): Second Participant Vehicle ID
  - Character field indicates second vehicle involved in the event
  - Vehicle ID has a letter value assigned to them
  - Cannot contain NULL values

- **VEHICLE_2_COLL_PT** (CHAR): Point of Collision 2
  - Character field indicates collision point on the second vehicle
  - Cannot contain NULL values

- **VEHICLE_2_COLL_PT_DESC** (VARCHAR): Vehicle 2 Collision Point Description
  - Descriptive field that indicates collision point on the second vehicle
  - Cannot contain NULL values
  - Values: Same as VEHICLE_1_COLL_PT_DESC

### Person and Object Information

- **PERSON_ID** (CHAR): Person ID
  - Uniquely identifies each person involved in the accident
  - Persons who are drivers of a vehicle have a letter value assigned to them
  - Persons who are not drivers have a numerical value assigned to them

- **OBJECT_TYPE** (CHAR): Object Type
  - Character field that identifies object involved in the specific accident event
  - Cannot contain NULL values
  - Values:
    1. Pole (telephone/electricity)
    2. Tree (shrub/scrub)
    3. Fence/Wall (including gates)
    17. Traffic island

- **OBJECT_TYPE_DESC** (VARCHAR): Object Type Description
  - Descriptive field that identifies object involved in the specific accident event
  - Cannot contain NULL values
  - Values: Same as OBJECT_TYPE

---

## Notes

### General Notes
- The DCA (Definitions for Classifying Accidents) system provides a comprehensive classification scheme for different types of accidents
- Time accuracy may be limited due to police arriving after the accident occurred
- Several fields can contain NULL values, which should be handled appropriately in analysis
- The speed zone field uses specific codes, including special codes for "other" (777), "camping grounds/off road" (888), and "not known" (999)

### Vehicle Table Specific Notes
- Many vehicle specification fields (body style, make, power, weight, etc.) depend on successful matching between the accident database and the VRIS (Vehicle Registration Information System) database
- The VRIS match is based on the registration number with confirmation of the date of expiry and the owner's name
- When VRIS matching fails, these fields may contain NULL values or default/unknown codes
- Vehicle DCA code links each vehicle to its specific movement/role in the accident as described in the DCA table
- Initial and final directions help track vehicle movement through turns and maneuvers

### Sub DCA Table Specific Notes
- Sub DCA codes provide detailed classification beyond the main DCA code
- Multiple Sub DCA codes can be associated with a single accident (indicated by SUB_DCA_SEQ)
- Sub DCA codes are organized into categories (A-Z) covering various aspects of the accident scenario
- These codes provide granular detail about pedestrian activity, vehicle movement, road conditions, objects hit, and other specific circumstances

### Person Table Specific Notes
- PERSON_ID uniquely identifies each person; drivers are assigned letters, non-drivers are assigned numbers
- Injury level is calculated from police injury level and hospital admission status
- Road user type is calculated from person status and vehicle type
- Seating position is only applicable for vehicle occupants; pedestrians and cyclists will have "Not applicable"
- The relationship between persons and vehicles is established through VEHICLE_ID
- Ejection status is only relevant for vehicle occupants

### Node Table Specific Notes
- NODE_ID identifies unique crash locations; multiple accidents can occur at the same node
- AMG (Australian Map Grid) coordinates use a projected coordinate system; latitude/longitude provide geographic coordinates
- Zero values in AMG_X/AMG_Y indicate location unknown accidents
- DEG_URBAN_NAME is critical for urban/rural classification in analysis
- LGA_NAME provides administrative boundary information for the crash location

### Atmospheric Condition Table Specific Notes
- Multiple atmospheric conditions can be recorded for a single accident (indicated by ATMOSPH_COND_SEQ)
- The sequence number allows tracking of changing weather conditions during an accident sequence
- Clear conditions (code 1) are the most common in Australian crash data

### Accident Event Table Specific Notes
- Multiple events can occur in a single accident (indicated by EVENT_SEQ_NO), allowing for sequential event analysis
- Vehicle collision points (VEHICLE_1_COLL_PT, VEHICLE_2_COLL_PT) indicate impact locations on each vehicle
- The table can record collisions between vehicles, vehicles and objects, or involve persons directly
- OBJECT_TYPE is only relevant when the event involves a collision with a fixed object
- This table provides granular detail about the sequence and nature of events within an accident

---

## Road Surface Condition Table (`road_surface_cond.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **SURFACE_COND_SEQ** (INTEGER): Surface Condition Sequence
  - Starts with 1 and incremented by 1 if more than one road surface condition is entered for the same incident

### Road Surface Conditions

- **SURFACE_COND** (CHAR): Surface Condition
  - Road surface conditions on which the crash occurred (e.g., dry, wet, muddy)
  - Values:
    1. Dry
    2. Wet
    3. Muddy
    4. Snowy
    5. Icy
    9. Unknown

- **SURFACE_COND_DESC** (VARCHAR): Surface Condition Description
  - Descriptive field that indicates road surface conditions on which the crash occurred
  - Values: Same as SURFACE_COND (Dry, Wet, Muddy, Snowy, Icy, Unknown)

---

## Accident Location Table (`accident_location.csv`)

### Primary Keys
- **ACCIDENT_NO** (CHAR): Accident Number - Primary Key linking to the accident table
  - First character T indicates TIS incident
  - Characters 2-5 typically represent the year in which the accident was created in TIS system
  - Characters 6-11 are a numeric sequencing number
  - Cannot contain NULL values

- **NODE_ID** (INTEGER): Node ID
  - The node id of the accident
  - Starts at 1 and incremented by one when a new accident location is identified

### Road Information

- **ROAD_ROUTE_1** (INTEGER): Road Route 1
  - Character field indicates primary route for Road_Name_1
  - NULL values are valid entries
  - Group Classifications:
    - 2000-2999: Freeways or Highways
    - 3000-3999: Forest Roads
    - 4000-4999: Tourist Roads
    - 5000-5999: Main Roads
    - 7000-7999: Ramps (mainly Freeway ramps)
    - 9999: Unclassified Roads (e.g., Council/Local roads)

- **ROAD_NAME** (NVARCHAR): Road Name
  - Character field indicates highest priority road at intersection OR road on which accident took place

- **ROAD_TYPE** (NVARCHAR): Road Type
  - Character field indicates type of Road_Name

- **ROAD_NAME_INT** (NVARCHAR): Road Name Intersection
  - Character field indicates other road at intersection OR nearest intersecting road (on_road)

- **ROAD_TYPE_INT** (NVARCHAR): Road Type Intersection
  - Character field indicates type of Road_Name_Int at intersection OR nearest intersecting road (on_road)

### Location Details

- **DISTANCE_LOCATION** (INTEGER): Distance
  - Integer field indicating the distance (in metres) of the accident from the nearest intersecting road
  - Only applicable if the crash is a non-intersection or mid-block accident

- **DIRECTION_LOCATION** (NVARCHAR): Direction
  - Character field indicating the direction of the accident from the nearest intersecting road
  - Only applicable if the crash is a non-intersection or mid-block accident
  - Cannot contain NULL values
  - Values:
    - N: North
    - NE: North East
    - E: East
    - SE: South East
    - S: South
    - SW: South West
    - W: West
    - NW: North West
    - UK: Not known

---

## Notes

### General Notes
- The DCA (Definitions for Classifying Accidents) system provides a comprehensive classification scheme for different types of accidents
- Time accuracy may be limited due to police arriving after the accident occurred
- Several fields can contain NULL values, which should be handled appropriately in analysis
- The speed zone field uses specific codes, including special codes for "other" (777), "camping grounds/off road" (888), and "not known" (999)

### Vehicle Table Specific Notes
- Many vehicle specification fields (body style, make, power, weight, etc.) depend on successful matching between the accident database and the VRIS (Vehicle Registration Information System) database
- The VRIS match is based on the registration number with confirmation of the date of expiry and the owner's name
- When VRIS matching fails, these fields may contain NULL values or default/unknown codes
- Vehicle DCA code links each vehicle to its specific movement/role in the accident as described in the DCA table
- Initial and final directions help track vehicle movement through turns and maneuvers

### Sub DCA Table Specific Notes
- Sub DCA codes provide detailed classification beyond the main DCA code
- Multiple Sub DCA codes can be associated with a single accident (indicated by SUB_DCA_SEQ)
- Sub DCA codes are organized into categories (A-Z) covering various aspects of the accident scenario
- These codes provide granular detail about pedestrian activity, vehicle movement, road conditions, objects hit, and other specific circumstances

### Person Table Specific Notes
- PERSON_ID uniquely identifies each person; drivers are assigned letters, non-drivers are assigned numbers
- Injury level is calculated from police injury level and hospital admission status
- Road user type is calculated from person status and vehicle type
- Seating position is only applicable for vehicle occupants; pedestrians and cyclists will have "Not applicable"
- The relationship between persons and vehicles is established through VEHICLE_ID
- Ejection status is only relevant for vehicle occupants

### Node Table Specific Notes
- NODE_ID identifies unique crash locations; multiple accidents can occur at the same node
- AMG (Australian Map Grid) coordinates use a projected coordinate system; latitude/longitude provide geographic coordinates
- Zero values in AMG_X/AMG_Y indicate location unknown accidents
- DEG_URBAN_NAME is critical for urban/rural classification in analysis
- LGA_NAME provides administrative boundary information for the crash location

### Atmospheric Condition Table Specific Notes
- Multiple atmospheric conditions can be recorded for a single accident (indicated by ATMOSPH_COND_SEQ)
- The sequence number allows tracking of changing weather conditions during an accident sequence
- Clear conditions (code 1) are the most common in Australian crash data

### Accident Event Table Specific Notes
- Multiple events can occur in a single accident (indicated by EVENT_SEQ_NO), allowing for sequential event analysis
- Vehicle collision points (VEHICLE_1_COLL_PT, VEHICLE_2_COLL_PT) indicate impact locations on each vehicle
- The table can record collisions between vehicles, vehicles and objects, or involve persons directly
- OBJECT_TYPE is only relevant when the event involves a collision with a fixed object
- This table provides granular detail about the sequence and nature of events within an accident

### Road Surface Condition Table Specific Notes
- Multiple road surface conditions can be recorded for a single accident (indicated by SURFACE_COND_SEQ)
- The sequence number allows tracking of changing road surface conditions during an accident sequence
- Dry conditions (code 1) are the most common in Australian crash data
- Wet road surfaces (code 2) significantly impact crash risk and severity

### Accident Location Table Specific Notes
- ROAD_ROUTE_1 provides hierarchical classification of road types (freeways, highways, main roads, local roads)
- ROAD_NAME and ROAD_NAME_INT identify the primary and intersecting roads
- DISTANCE_LOCATION and DIRECTION_LOCATION are only applicable for mid-block/non-intersection crashes
- This table provides detailed road identification information beyond the geographic coordinates in the node table

