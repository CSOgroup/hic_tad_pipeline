import numpy as np

def write_dense_matrix_with_coords(mat, bins, path):
    chrom_col = bins["chrom"].values
    starts = bins["start"].values
    ends = bins["end"].values
    with open(path, "w") as f:
        for i in range(len(bins)):
            row = "\t".join(f"{v:.6g}" for v in mat[i])
            f.write(f"{chrom_col[i]}\t{starts[i]}\t{ends[i]}\t{row}\n")

def write_dense_matrix_no_coords(mat, path):
    with open(path, "w") as f:
        for i in range(mat.shape[0]):
            row = "\t".join(f"{v:.6g}" for v in mat[i])
            f.write(row + "\n")

def write_sparse_matrix_bin1_dedoc(mat, path):
    n = mat.shape[0]
    rows, cols = np.triu_indices(n, k=1)
    mask = mat[rows, cols] > 0
    with open(path, "w") as fh:
        fh.write(f"{n}\n")
        for r, c, v in zip(rows[mask] + 1, cols[mask] + 1, mat[rows[mask], cols[mask]]):
            fh.write(f"{r} {c} {v}\n")

def write_sparse_matrix_coords(mat, bins, path):
    starts = bins["start"].values
    n = mat.shape[0]
    rows, cols = np.triu_indices(n, k=0)
    mask = mat[rows, cols] > 0
    with open(path, "w") as fh:
        for r, c, v in zip(rows[mask], cols[mask], mat[rows[mask], cols[mask]]):
            fh.write(f"{starts[r]}\t{starts[c]}\t{v:.6g}\n")
