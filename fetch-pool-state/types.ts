export interface PoolObject {
    content: {
        fields: {
            unclaimed: {
                type: string;
                fields: {
                    id: {
                        id: string;
                    };
                    size: string;
                };
            };
        };
    };
}
