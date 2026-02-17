import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle_listing.dart';

void main() {
  group('ListingStatus', () {
    test('fromString returns correct enum value', () {
      expect(ListingStatus.fromString('active'), ListingStatus.active);
      expect(ListingStatus.fromString('reserved'), ListingStatus.reserved);
      expect(ListingStatus.fromString('sold'), ListingStatus.sold);
      expect(ListingStatus.fromString('withdrawn'), ListingStatus.withdrawn);
    });

    test('fromString returns null for invalid value', () {
      expect(ListingStatus.fromString('invalid'), isNull);
      expect(ListingStatus.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(ListingStatus.active.displayName, '販売中');
      expect(ListingStatus.reserved.displayName, '商談中');
      expect(ListingStatus.sold.displayName, '売約済み');
    });
  });

  group('ConditionGrade', () {
    test('fromString returns correct enum value', () {
      expect(ConditionGrade.fromString('s'), ConditionGrade.s);
      expect(ConditionGrade.fromString('a'), ConditionGrade.a);
      expect(ConditionGrade.fromString('b'), ConditionGrade.b);
    });

    test('displayName returns full description', () {
      expect(ConditionGrade.s.displayName, 'S（新車・未使用車）');
      expect(ConditionGrade.a.displayName, 'A（極上車）');
    });

    test('shortName returns single character', () {
      expect(ConditionGrade.s.shortName, 'S');
      expect(ConditionGrade.c.shortName, 'C');
    });
  });

  group('TransmissionType', () {
    test('fromString returns correct enum value', () {
      expect(TransmissionType.fromString('at'), TransmissionType.at);
      expect(TransmissionType.fromString('mt'), TransmissionType.mt);
      expect(TransmissionType.fromString('cvt'), TransmissionType.cvt);
    });

    test('displayName returns correct name', () {
      expect(TransmissionType.at.displayName, 'AT');
      expect(TransmissionType.mt.displayName, 'MT');
      expect(TransmissionType.cvt.displayName, 'CVT');
    });
  });

  group('FuelType', () {
    test('fromString returns correct enum value', () {
      expect(FuelType.fromString('gasoline'), FuelType.gasoline);
      expect(FuelType.fromString('diesel'), FuelType.diesel);
      expect(FuelType.fromString('hybrid'), FuelType.hybrid);
      expect(FuelType.fromString('ev'), FuelType.ev);
    });

    test('displayName returns Japanese name', () {
      expect(FuelType.gasoline.displayName, 'ガソリン');
      expect(FuelType.hybrid.displayName, 'ハイブリッド');
      expect(FuelType.ev.displayName, 'EV');
    });
  });

  group('DriveType', () {
    test('fromString returns correct enum value', () {
      expect(DriveType.fromString('fwd'), DriveType.fwd);
      expect(DriveType.fromString('rwd'), DriveType.rwd);
      expect(DriveType.fromString('awd'), DriveType.awd);
      expect(DriveType.fromString('4wd'), DriveType.fourWd);
    });

    test('storageName returns correct storage name', () {
      expect(DriveType.fourWd.storageName, '4wd');
      expect(DriveType.awd.storageName, 'awd');
    });
  });

  group('ListingImage', () {
    test('creates with required fields', () {
      const image = ListingImage(
        url: 'https://example.com/image.jpg',
        order: 0,
        isPrimary: true,
      );

      expect(image.url, 'https://example.com/image.jpg');
      expect(image.isPrimary, true);
    });

    test('fromMap creates from map', () {
      final image = ListingImage.fromMap({
        'url': 'https://example.com/image.jpg',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'order': 1,
        'isPrimary': false,
        'caption': 'エクステリア',
      });

      expect(image.url, 'https://example.com/image.jpg');
      expect(image.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(image.order, 1);
      expect(image.caption, 'エクステリア');
    });

    test('toMap converts to map', () {
      const image = ListingImage(
        url: 'https://example.com/image.jpg',
        order: 0,
        isPrimary: true,
        caption: 'フロント',
      );

      final map = image.toMap();

      expect(map['url'], 'https://example.com/image.jpg');
      expect(map['isPrimary'], true);
      expect(map['caption'], 'フロント');
    });
  });

  group('VehicleSpecs', () {
    test('creates with specs', () {
      const specs = VehicleSpecs(
        engineDisplacement: 2000,
        maxPower: 150,
        fuelEfficiency: 15.5,
        transmission: TransmissionType.at,
        fuelType: FuelType.gasoline,
        driveType: DriveType.fwd,
      );

      expect(specs.engineDisplacement, 2000);
      expect(specs.maxPower, 150);
      expect(specs.fuelEfficiency, 15.5);
      expect(specs.transmission, TransmissionType.at);
    });

    test('fromMap handles null map', () {
      final specs = VehicleSpecs.fromMap(null);

      expect(specs.engineDisplacement, isNull);
      expect(specs.transmission, isNull);
    });

    test('toMap converts to map', () {
      const specs = VehicleSpecs(
        engineDisplacement: 1800,
        seatingCapacity: 5,
        transmission: TransmissionType.cvt,
      );

      final map = specs.toMap();

      expect(map['engineDisplacement'], 1800);
      expect(map['seatingCapacity'], 5);
      expect(map['transmission'], 'cvt');
    });
  });

  group('VehicleListing', () {
    late VehicleListing listing;

    setUp(() {
      listing = VehicleListing(
        id: 'listing1',
        sellerId: 'seller1',
        shopId: 'shop1',
        status: ListingStatus.active,
        makerId: 'toyota',
        makerName: 'トヨタ',
        modelId: 'prius',
        modelName: 'プリウス',
        gradeName: 'S',
        modelYear: 2022,
        bodyType: 'sedan',
        color: 'ホワイトパール',
        mileage: 15000,
        conditionGrade: ConditionGrade.a,
        inspectionDate: '2025-03',
        specs: const VehicleSpecs(
          engineDisplacement: 1800,
          transmission: TransmissionType.cvt,
          fuelType: FuelType.hybrid,
        ),
        features: ['ナビ', 'ETC', 'バックカメラ'],
        price: 2500000,
        totalPrice: 2800000,
        images: [
          const ListingImage(
            url: 'https://example.com/img1.jpg',
            isPrimary: true,
          ),
        ],
        prefecture: '東京都',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    });

    test('displayTitle combines maker, model and grade', () {
      expect(listing.displayTitle, 'トヨタ プリウス S');
    });

    test('displayPrice formats price with yen symbol', () {
      expect(listing.displayPrice, '¥2,500,000');
    });

    test('displayTotalPrice formats total price', () {
      expect(listing.displayTotalPrice, '¥2,800,000');
    });

    test('displayMileage formats mileage', () {
      expect(listing.displayMileage, '1.5万km');

      final lowMileage = listing.copyWith(mileage: 5000);
      expect(lowMileage.displayMileage, '5000km');
    });

    test('primaryImageUrl returns primary image', () {
      expect(listing.primaryImageUrl, 'https://example.com/img1.jpg');
    });

    test('isShopListing returns true for shop listing', () {
      expect(listing.isShopListing, true);

      final privateListing = listing.copyWith(shopId: null);
      // Note: copyWith doesn't allow setting to null, create new
      final privateListingNew = VehicleListing(
        id: 'listing2',
        sellerId: 'seller1',
        status: ListingStatus.active,
        makerId: 'toyota',
        makerName: 'トヨタ',
        modelId: 'prius',
        modelName: 'プリウス',
        modelYear: 2022,
        mileage: 10000,
        conditionGrade: ConditionGrade.b,
        price: 2000000,
        prefecture: '大阪府',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(privateListingNew.isShopListing, false);
    });

    test('isActive returns true for active listing', () {
      expect(listing.isActive, true);

      final soldListing = listing.copyWith(status: ListingStatus.sold);
      expect(soldListing.isActive, false);
    });

    test('toMap converts to map correctly', () {
      final map = listing.toMap();

      expect(map['sellerId'], 'seller1');
      expect(map['shopId'], 'shop1');
      expect(map['status'], 'active');
      expect(map['makerId'], 'toyota');
      expect(map['makerName'], 'トヨタ');
      expect(map['price'], 2500000);
      expect(map['mileage'], 15000);
      expect(map['features'], ['ナビ', 'ETC', 'バックカメラ']);
    });

    test('copyWith creates modified copy', () {
      final modified = listing.copyWith(
        price: 2300000,
        status: ListingStatus.reserved,
      );

      expect(modified.price, 2300000);
      expect(modified.status, ListingStatus.reserved);
      expect(modified.makerId, listing.makerId);
    });

    test('equality is based on id', () {
      final listing2 = listing.copyWith(price: 2000000);

      expect(listing == listing2, true);
      expect(listing.hashCode, listing2.hashCode);
    });

    test('toString returns readable format', () {
      expect(listing.toString(), 'VehicleListing(トヨタ プリウス S, ¥2,500,000)');
    });
  });

  group('ListingFavorite', () {
    test('creates with required fields', () {
      final favorite = ListingFavorite(
        id: 'fav1',
        listingId: 'listing1',
        userId: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(favorite.listingId, 'listing1');
      expect(favorite.userId, 'user1');
    });

    test('toMap converts to map', () {
      final favorite = ListingFavorite(
        id: 'fav1',
        listingId: 'listing1',
        userId: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      final map = favorite.toMap();

      expect(map['listingId'], 'listing1');
      expect(map['userId'], 'user1');
    });
  });
}
