import 'product_group.dart';

/// Node in a hierarchical product group tree.
class ProductGroupTreeNode {
  const ProductGroupTreeNode({required this.group, this.children = const []});

  final ProductGroup group;
  final List<ProductGroupTreeNode> children;
}

/// Builds a sorted tree from a flat [ProductGroup] list.
List<ProductGroupTreeNode> buildProductGroupTree(List<ProductGroup> groups) {
  final groupIds = groups.map((group) => group.id).toSet();
  final byParent = <String?, List<ProductGroup>>{};
  for (final group in groups) {
    final parentId = group.parentId;
    final effectiveParentId = parentId != null && groupIds.contains(parentId)
        ? parentId
        : null;
    byParent.putIfAbsent(effectiveParentId, () => []).add(group);
  }
  for (final list in byParent.values) {
    list.sort(_compareGroups);
  }

  final visited = <String>{};

  ProductGroupTreeNode buildNode(ProductGroup group, Set<String> path) {
    visited.add(group.id);
    final nextPath = {...path, group.id};
    final children = (byParent[group.id] ?? [])
        .where((child) => !nextPath.contains(child.id))
        .map((child) => buildNode(child, nextPath))
        .toList();
    return ProductGroupTreeNode(group: group, children: children);
  }

  final roots = (byParent[null] ?? [])
      .map((group) => buildNode(group, const {}))
      .toList();
  final result = [...roots];
  final remaining = [...groups]..sort(_compareGroups);
  for (final group in remaining) {
    if (visited.contains(group.id)) continue;
    result.add(buildNode(group, const {}));
  }

  return result;
}

int _compareGroups(ProductGroup a, ProductGroup b) {
  final sortCompare = a.sortOrder.compareTo(b.sortOrder);
  if (sortCompare != 0) return sortCompare;
  return a.nameEn.compareTo(b.nameEn);
}
