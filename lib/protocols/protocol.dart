/// OBD physical/link protocol (ISO 15765-4 CAN, ISO 9141-2, etc)
abstract class Protocol {
  final String name;
  final String elmCode; // ELM 'ATSP' code (0..A etc)
  const Protocol(this.name, this.elmCode);

  @override
  String toString() => name;
}

class AutoProtocol extends Protocol {
  const AutoProtocol() : super('AUTO', '0');
}

class ISO15765_4_CAN_11bit_500k extends Protocol {
  const ISO15765_4_CAN_11bit_500k() : super('ISO 15765-4 (CAN 11/500)', '6');
}

class ISO15765_4_CAN_29bit_500k extends Protocol {
  const ISO15765_4_CAN_29bit_500k() : super('ISO 15765-4 (CAN 29/500)', '7');
}

class ISO15765_4_CAN_11bit_250k extends Protocol {
  const ISO15765_4_CAN_11bit_250k() : super('ISO 15765-4 (CAN 11/250)', '8');
}

class ISO15765_4_CAN_29bit_250k extends Protocol {
  const ISO15765_4_CAN_29bit_250k() : super('ISO 15765-4 (CAN 29/250)', '9');
}

class ISO9141_2 extends Protocol {
  const ISO9141_2() : super('ISO 9141-2', '3');
}

class KWP2000_FAST extends Protocol {
  const KWP2000_FAST() : super('ISO 14230-4 (KWP FAST)', '5');
}

class KWP2000_5BAUD extends Protocol {
  const KWP2000_5BAUD() : super('ISO 14230-4 (KWP 5BAUD)', '4');
}

class SAE_J1850_PWM extends Protocol {
  const SAE_J1850_PWM() : super('SAE J1850 PWM', '1');
}

class SAE_J1850_VPW extends Protocol {
  const SAE_J1850_VPW() : super('SAE J1850 VPW', '2');
}
