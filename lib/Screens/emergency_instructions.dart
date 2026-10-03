import 'package:flutter/material.dart';

class EmergencyInstructionsScreen extends StatefulWidget {
  const EmergencyInstructionsScreen({super.key});

  @override
  State<EmergencyInstructionsScreen> createState() =>
      _EmergencyInstructionsScreenState();
}

class _EmergencyInstructionsScreenState
    extends State<EmergencyInstructionsScreen> {
  String selectedDisaster = 'Flood';

  final Map<String, List<String>> instructions = {
    'Flood': [
      'Move to higher ground immediately.',
      'Do not walk or drive through moving flood water.',
      'Keep your phone charged and conserve battery.',
      'Stay away from electrical wires and damaged buildings.',
      'Follow instructions from rescue authorities.',
    ],
    'Earthquake': [
      'Drop, Cover, and Hold On.',
      'Stay away from windows and falling objects.',
      'If outdoors, move away from buildings and power lines.',
      'Do not use elevators.',
      'After the shaking stops, move to a safe open area.',
    ],
    'Landslide': [
      'Move away from the path of falling rocks or debris.',
      'Move to stable and higher ground if possible.',
      'Stay away from rivers and steep slopes.',
      'Watch for additional landslides.',
      'Follow evacuation instructions from authorities.',
    ],
    'Cyclone': [
      'Stay indoors and away from windows.',
      'Secure loose objects if it is safe to do so.',
      'Keep emergency supplies and water ready.',
      'Avoid flooded roads and coastal areas.',
      'Wait for the official all-clear before going outside.',
    ],
    'Fire': [
      'Raise the alarm and call emergency services.',
      'Leave the building using the nearest safe exit.',
      'Do not use elevators.',
      'Stay low if there is smoke.',
      'Never return to a burning building.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final List<String> currentInstructions =
    instructions[selectedDisaster]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Emergency Instructions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stay Safe',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Select the emergency situation to view basic safety instructions.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Emergency Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // DISASTER DROPDOWN
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 15),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),

                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDisaster,
                    isExpanded: true,

                    items: const [
                      DropdownMenuItem(
                        value: 'Flood',
                        child: Text('🌊  Flood'),
                      ),
                      DropdownMenuItem(
                        value: 'Earthquake',
                        child: Text('🏚️  Earthquake'),
                      ),
                      DropdownMenuItem(
                        value: 'Landslide',
                        child: Text('⛰️  Landslide'),
                      ),
                      DropdownMenuItem(
                        value: 'Cyclone',
                        child: Text('🌪️  Cyclone'),
                      ),
                      DropdownMenuItem(
                        value: 'Fire',
                        child: Text('🔥  Fire'),
                      ),
                    ],

                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          selectedDisaster = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Text(
                '$selectedDisaster Safety Instructions',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // INSTRUCTION CARDS
              ...List.generate(
                currentInstructions.length,
                    (index) {
                  return Container(
                    width: double.infinity,

                    margin:
                    const EdgeInsets.only(bottom: 12),

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(14),

                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),

                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Container(
                          height: 28,
                          width: 28,

                          decoration: BoxDecoration(
                            color:
                            Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),

                          child: Center(
                            child: Text(
                              '${index + 1}',

                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            currentInstructions[index],

                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // IMPORTANT NOTICE
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius:
                  BorderRadius.circular(14),
                ),

                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'These are basic safety guidelines. Always follow instructions from local emergency authorities.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}