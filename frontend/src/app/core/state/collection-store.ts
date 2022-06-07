import {
  applyTransaction,
  EntityState,
  EntityStore,
  ID,
} from '@datorama/akita';
import { IHALCollection } from 'core-app/core/apiv3/types/hal-collection.type';
import {
  ApiV3ListParameters,
  listParamsString,
} from 'core-app/core/apiv3/paths/apiv3-list-resource.interface';

export interface CollectionResponse {
  ids:ID[];
}

export interface CollectionState<T> extends EntityState<T> {
  /** Loaded notification collections */
  collections:Record<string, CollectionResponse>;
}

export interface CollectionItem {
  id:ID;
}

export function mapHALCollectionToIDCollection<T extends CollectionItem>(collection:IHALCollection<T>):CollectionResponse {
  return {
    ids: collection._embedded.elements.map((el) => el.id),
  };
}

/**
 * Initialize the collection part of the entity store
 */
export function createInitialCollectionState():{ collections:Record<string, CollectionResponse> } {
  return {
    collections: {},
  };
}

/**
 * Returns the collection key for the given APIv3 parameters
 *
 * @param params list params
 */
export function collectionKey(params:ApiV3ListParameters):string {
  return listParamsString(params);
}

/**
 * Insert a collection into the given entity store
 *
 * @param store An entity store for the collection
 * @param collection A loaded collection
 * @param collectionUrl The key to insert the collection at
 */
export function insertCollectionIntoState<T extends { id:ID }>(
  store:EntityStore<CollectionState<T>>,
  collection:IHALCollection<T>,
  collectionUrl:string,
):void {
  const { elements } = collection._embedded as { elements:undefined|T[] };

  // Some JSON endpoints return no elements result if there are no elements
  const ids = elements?.map((el) => el.id) || [];

  applyTransaction(() => {
    // Avoid inserting when elements is not defined
    if (elements && elements.length > 0) {
      store.upsertMany(elements);
    }

    store.update(({ collections }) => (
      {
        collections: {
          ...collections,
          [collectionUrl]: {
            ids,
          },
        },
      }
    ));
  });
}
