include("inverse.jl")

MODE = "bfgs_noadam"

make_directory("data/result$MODE")
include("../optimizers.jl")
# run(sess, loss)
losses = Optimize!(sess, loss; vars = [θ1, θ2], optimizer = BFGSOptimizer(), max_num_iter=1000)

THETA1, THETA2 = run(sess, [θ1, θ2])

@save "data/result$MODE/data.jld2" THETA1 THETA2 losses

close("all")
semilogy(losses)
savefig("data/result$MODE/loss.png")

E_, nu_ = run(sess, [E, nu])
close("all")
figure(figsize=(10,4))
subplot(121)
visualize_scalar_on_gauss_points(E_, mmesh)
subplot(122)
visualize_scalar_on_gauss_points(nu_, mmesh)
savefig("data/result$MODE/final.png")
