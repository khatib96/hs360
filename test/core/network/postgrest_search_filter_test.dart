import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/network/postgrest_search_filter.dart';

void main() {
  test('quotes the search value for every column', () {
    expect(
      ilikeAnyColumnFilter(['code', 'name_en'], 'abc'),
      'code.ilike."%abc%",name_en.ilike."%abc%"',
    );
  });

  test('keeps filter syntax typed by the user inside the quoted value', () {
    expect(
      ilikeAnyColumnFilter(['name_en'], 'Al Noor, Co.(x):is_active.eq.false'),
      'name_en.ilike."%Al Noor, Co.(x):is_active.eq.false%"',
    );
  });

  test('escapes double quotes and backslashes', () {
    expect(
      ilikeAnyColumnFilter(['name_en'], r'5" pipe \ x'),
      r'name_en.ilike."%5\" pipe \\ x%"',
    );
  });
}
