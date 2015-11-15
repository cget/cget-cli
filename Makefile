default:
	mkdir -p bin && cd bin && cmake -DCMAKE_BUILD_TYPE=Debug .. && make

arm:
	mkdir -p bin_arm && cd bin_arm && cmake -DCMAKE_TOOLCHAIN_FILE=toolchains/buildarm.cmake .. && make

clean:
	rm -rf bin && rm -rf bin_arm
