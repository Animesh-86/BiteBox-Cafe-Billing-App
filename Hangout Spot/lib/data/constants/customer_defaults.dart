class CustomerDefaults {
  static const walkInId = 'customer-walkin-default';
  static const zomatoId = 'customer-zomato-default';
  static const swiggyId = 'customer-swiggy-default';

  static const walkInName = 'Walk-in';
  static const zomatoName = 'Zomato';
  static const swiggyName = 'Swiggy';

  static const seeded = <({String id, String name})>[
    (id: walkInId, name: walkInName),
    (id: zomatoId, name: zomatoName),
    (id: swiggyId, name: swiggyName),
  ];
}
