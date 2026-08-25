
class Bill{
int? id;
String? name;
double? amount;
DateTime? date;
}

Map<String, dynamic> billToMap(Bill bill){
  return {
    'id':bill.id,
    'name':bill.name,
    'amount':bill.amount,
    'date':bill.date?.toIso8601String(),
  };
}