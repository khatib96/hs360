import '../../../core/documents/domain/document_kind.dart';
import 'contract_detail.dart';

DocumentKind documentKindForContract() => DocumentKind.contract;

bool isContractPrintable(ContractDetail detail) => true;
