class SubeDemoShipment {
  const SubeDemoShipment(this.ref, this.recipient, this.filter, this.tone);
  final String ref;
  final String recipient;
  final String filter;
  final String tone;
}

class SubeDemoCourier {
  const SubeDemoCourier(this.name, this.status, this.tone, this.onMe, this.left);
  final String name;
  final String status;
  final String tone;
  final int onMe;
  final int left;
}

const kSubeDemoShipments = [
  SubeDemoShipment('JL100238546 TR', 'Ahmet Yılmaz', 'waiting', 'mid'),
  SubeDemoShipment('JL100238547 TR', 'Ayşe Demir', 'out', 'lime'),
  SubeDemoShipment('JL100238548 TR', 'Mehmet Kaya', 'sla', 'hi'),
  SubeDemoShipment('JL100238549 TR', 'Zeynep Arslan', 'done', 'lo'),
  SubeDemoShipment('JL100238550 TR', 'Elif Koç', 'failed', 'hi'),
  SubeDemoShipment('JL100238551 TR', 'Fatma Şahin', 'booked', 'mid'),
  SubeDemoShipment('JL100238552 TR', 'Can Yıldız', 'return', 'mid'),
];

const kSubeDemoCouriers = [
  SubeDemoCourier('Ali Can', 'available', 'lime', 12, 8),
  SubeDemoCourier('Mert Demir', 'available', 'lime', 9, 6),
  SubeDemoCourier('Ece Yılmaz', 'available', 'lime', 7, 4),
  SubeDemoCourier('Barış Arslan', 'available', 'lime', 0, 0),
];
