// app/src/types/utils.ts
/**
 * Utility types for SysNDD application
 * Includes branded types for compile-time type safety
 */

declare const __brand: unique symbol;

/**
 * Create a branded type - adds compile-time type safety without runtime cost
 * Use this to create distinct types for different kinds of IDs
 * @example
 * type GeneId = Brand<string, 'GeneId'>;
 * type EntityId = Brand<string, 'EntityId'>;
 */
export type Brand<T, TBrand extends string> = T & { [__brand]: TBrand };

/**
 * Generic nullable type
 */
export type Nullable<T> = T | null;

/**
 * Make specific properties optional
 */
export type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

/**
 * Make specific properties required
 */
export type RequiredBy<T, K extends keyof T> = Omit<T, K> & Required<Pick<T, K>>;
