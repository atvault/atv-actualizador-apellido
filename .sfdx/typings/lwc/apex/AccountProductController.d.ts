declare module "@salesforce/apex/AccountProductController.getRelatedProducts" {
  export default function getRelatedProducts(param: {accountId: any}): Promise<any>;
}
declare module "@salesforce/apex/AccountProductController.deleteAccountProducts" {
  export default function deleteAccountProducts(param: {accountProductIds: any, accountId: any}): Promise<any>;
}
declare module "@salesforce/apex/AccountProductController.createAccountProduct" {
  export default function createAccountProduct(param: {accountId: any, productId: any, cantidad: any, frecuencia: any, precio: any}): Promise<any>;
}
