#ifndef _C_DECHUNKER_H_
#define _C_DECHUNKER_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _PassengerDechunker PassengerDechunker;
typedef void (*PassengerDechunkerCallback)(const char *data, size_t size, void *userData);

PassengerDechunker *passenger_dechunker_new();
void passenger_dechunker_free(PassengerDechunker *dck);
void passenger_dechunker_set_data_cb(PassengerDechunker *dck, PassengerDechunkerCallback cb);
void passenger_dechunker_set_user_data(PassengerDechunker *dck, void *userData);
void passenger_dechunker_reset(PassengerDechunker *dck);
size_t passenger_dechunker_feed(PassengerDechunker *dck, const char *data, size_t size);
int passenger_dechunker_accepting_input(PassengerDechunker *dck);
int passenger_dechunker_has_error(PassengerDechunker *dck);
const char *passenger_dechunker_get_error_message(PassengerDechunker *dck);

#ifdef __cplusplus
}
#endif

#endif /* _C_DECHUNKER_H_ */
