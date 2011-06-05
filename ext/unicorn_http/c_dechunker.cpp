#include "Dechunker.h"
#include "c_dechunker.h"

PassengerDechunker *
passenger_dechunker_new() {
	return (PassengerDechunker *) new Passenger::Dechunker();
}

void
passenger_dechunker_free(PassengerDechunker *dck) {
	delete (Passenger::Dechunker *) dck;
}

void
passenger_dechunker_set_data_cb(PassengerDechunker *dck, PassengerDechunkerCallback cb) {
	((Passenger::Dechunker *) dck)->onData = cb;
}

void
passenger_dechunker_set_user_data(PassengerDechunker *dck, void *userData) {
	((Passenger::Dechunker *) dck)->userData = userData;
}

void
passenger_dechunker_reset(PassengerDechunker *dck) {
	((Passenger::Dechunker *) dck)->reset();
}

size_t
passenger_dechunker_feed(PassengerDechunker *dck, const char *data, size_t size) {
	return ((Passenger::Dechunker *) dck)->feed(data, size);
}

int
passenger_dechunker_accepting_input(PassengerDechunker *dck) {
	return ((Passenger::Dechunker *) dck)->acceptingInput();
}

int
passenger_dechunker_has_error(PassengerDechunker *dck) {
	return ((Passenger::Dechunker *) dck)->hasError();
}

const char *
passenger_dechunker_get_error_message(PassengerDechunker *dck) {
	return ((Passenger::Dechunker *) dck)->getErrorMessage();
}
