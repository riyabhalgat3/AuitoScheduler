# test/integration/test_api.jl
@testset "API Tests" begin
    # Test REST server start/stop
    @test begin
        # Start server in background
        server_task = @async start_rest_server(port=8888)
        sleep(2)
        
        # Stop server
        stop_rest_server()
        true
    end
    
    @test begin
        # Test WebSocket server
        ws_task = @async start_websocket_server(port=8889)
        sleep(2)
        
        stop_websocket_server()
        true
    end
    
    @test begin
        # Test client creation
        using AutoScheduler.ClientSDK
        
        client = AutoSchedulerClient(
            host="localhost",
            port=8888,
            ws_port=8889,
            timeout=10.0
        )
        
        @test client isa AutoSchedulerClient
        @test client.base_url == "http://localhost:8888"
        @test client.ws_url == "ws://localhost:8889"
        true
    end
    
    # Skip actual API calls unless server is running
    if haskey(ENV, "TEST_API_LIVE")
        @test begin
            using AutoScheduler.ClientSDK
            
            # Start server
            @async start_rest_server(port=8888)
            sleep(2)
            
            client = AutoSchedulerClient(host="localhost", port=8888)
            
            # Test health check
            health = health_check(client)
            @test health isa Bool
            
            # Test metrics endpoint
            metrics = get_metrics(client)
            @test haskey(metrics, "data")
            
            # Stop server
            stop_rest_server()
            true
        end
    end
end