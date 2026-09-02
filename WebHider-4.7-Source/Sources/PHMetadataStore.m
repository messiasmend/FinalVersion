+ (void)synchronizeWithFilters {
    NSArray<NSDictionary *> *filters = PH47LoadFilters();
    NSMutableSet<NSString *> *activeSelectors = [NSMutableSet set];
    for (NSDictionary *filter in filters) {
        NSString *selector = PH47FilterSelector(filter);
        if (selector.length) [activeSelectors addObject:selector];
    }

    NSMutableDictionary *elements = [PH47LoadMetadata() mutableCopy];
    [PH47PendingMetadata() enumerateKeysAndObjectsUsingBlock:^(NSString *selector, NSDictionary *record, BOOL *stop) {
        if ([activeSelectors containsObject:selector]) elements[selector] = record;
    }];

    NSArray *staleKeys = [elements.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *key, NSDictionary *bindings) {
        return ![activeSelectors containsObject:key];
    }]];